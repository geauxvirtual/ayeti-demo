# Main terraform for deploying the demo onto AWS.

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "3.72.0"
    }
  }
}

# Define the AWS region to use for the demo.
variable "region" {
  description = "AWS Region to create resources in"
  default = "us-west-2"
  type = string
}

variable "demo_ami" {
  description = "AMI to use for demo"
  default = "ami-059cd301f2f1c6ce3"
  type = string
}

# Set up the region in the AWS provider.
provider "aws" {
  region = var.region
}

# Configure the AWS VPC to use for the demo.
# This subnet is way overkill for this simple demo,
# but will suffice. The nature of this demo will be four servers
# provisioned with static ip addresses. Ports will be opened for
# the UIs on Vault and Consul secured by TLS certificates pre-generated
# along with port 443 on the nginx server that will be provisioned as well.
resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true

  tags = {
    Name = "demo-vpc-1"
  }
}

# This is the demo subnet in address space 10.0.1.0/24
# Four nodes will be provisioned in this subnet.
# node1.example.local - 10.0.1.10
# node2.example.local - 10.0.1.11
# node3.example.local - 10.0.1.12
# web.example.local  - 10.0.1.20
resource "aws_subnet" "demo_subnet" {
  vpc_id = aws_vpc.vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-west-2a"
  map_public_ip_on_launch = true
  tags = {
    Name = "demo-subnet-1"
  }
} 

# Create a gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "demo-gw-1"
  }
}

# Create a route table
resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "demo-route-table-1"
  }
}

# Associate the demo subnet with the route table
resource "aws_route_table_association" "a" {
  subnet_id = aws_subnet.demo_subnet.id
  route_table_id = aws_route_table.route_table.id
}

# Create Vault/Consul security group
resource "aws_security_group" "demo-service" {
  name = "demo-service"
  description = "Allow access to Vault and Consul UI web pages"
  vpc_id = aws_vpc.vpc.id
  
  ingress {
    description = "Allow SSH"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS to Consul"
    from_port = 8501
    to_port = 8501
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
     description = "Allow HTTPS to Vault"
     from_port = 8200
     to_port = 8200
     protocol = "tcp"
     cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
     description = "Allow HTTPS Vault to Vault"
     from_port = 8201
     to_port = 8201
     protocol = "tcp"
     cidr_blocks = ["10.0.1.0/24"]
  }

  ingress {
    description = "Allow LAN SERF"
    from_port = 8301
    to_port = 8301
    protocol = "tcp"
    cidr_blocks = ["10.0.1.0/24"]
  }

  ingress {
    description = "Allow Server RPC"
    from_port = 8300
    to_port = 8300
    protocol = "tcp"
    cidr_blocks = ["10.0.1.0/24"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "demo-vault-conusl-security-group-1"
  }
}


# Vault AWS KMS key setup
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "vault-kms-unseal" {
  statement {
    sid = "VaultKMSUnseal"
    effect = "Allow"
    resources = ["*"]

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:DescribeKey",
      "ec2:DescribeInstances",
    ]
  }
}

resource "aws_iam_role" "vault-kms-unseal" {
  name = "vault-kms-role-demo-1"
  assume_role_policy = "${data.aws_iam_policy_document.assume_role.json}"
}

resource "aws_iam_role_policy" "vault-kms-unseal" {
  name = "Vault-KMS-Unseal-demo-1"
  role = "${aws_iam_role.vault-kms-unseal.id}"
  policy = "${data.aws_iam_policy_document.vault-kms-unseal.json}"
}

resource "aws_iam_instance_profile" "vault-kms-unseal" {
  name = "vault-kms-unseal-demo-1"
  role = "${aws_iam_role.vault-kms-unseal.name}"
}

resource "aws_kms_key" "vault" {
  description = "Vault unseal key"
  deletion_window_in_days = 10

  tags = {
    Name = "vault-kms-unseal-demo-1"
  }
}


############## Instance Configurations #################
# For demo purposes, we want to be able to SSH into our instances with a preset key.
# A key has been generated on the local computer, so let's load that into a variable.
# This could be defined as a variable that could easily be changed.
data "local_file" "ssh_pub_key" {
  filename = "../ssh/service-account.pub"
}

# There are certificate files we want to use to secure Vault and Consul.
# The same certs will be used to secure the UIs via HTTPs and the Vault
# to Consul communications.
# There does seem to be open issues around supporting sensitive_content with
# local_file dating back to 2018.
data "local_file" "ca_chain" {
  filename = "../tls/root/ca/intermediate/certs/ca-chain.cert.pem"
}

data "local_file" "node_cert" {
  filename = "../tls/root/ca/intermediate/certs/node.example.local.cert.pem"
}

data "local_file" "node_priv_key" {
  filename = "../tls/root/ca/intermediate/private/node.example.local.key.pem"
}

data "local_file" "node_consul_systemd_config" {
  filename = "./configs/node-consul-systemd-config"
}

data "local_file" "node_vault_systemd_config" {
  filename = "./configs/node-vault-systemd-config"
}

# 3 instances are going to be configued, each with a cloud-init file.
# Our packer generated Ubuntu Server 20.04 ami ami-0149f0001f48a7a19
resource "aws_network_interface" "node1" {
  subnet_id = aws_subnet.demo_subnet.id
  private_ips = ["10.0.1.10"]
  security_groups = [aws_security_group.demo-service.id]
  tags = {
    Name = "node1_network_interface"
  }
}

data "template_file" "node1_consul_config" {
  template = file("./configs/node-consul.hcl")
  vars = {
    node_name = "node1"
    node_ip = "10.0.1.10"
    node_a_name = "node2"
    node_b_name = "node3"
  }
}

data "template_file" "node1_vault_config" {
  template = file("./configs/node-vault-config.hcl")
  vars = {
    node_ip = "10.0.1.10"
    fqdn = "node1.example.local"
    region = var.region
    aws_kms_key = aws_kms_key.vault.id
  }
}

data "template_file" "node1_cloud_init" {
  template = file("./cloud-init/service-node-cloud-init")
  vars = {
    ssh_pub_key = "${data.local_file.ssh_pub_key.content}"
    ca_chain = "${indent(4, data.local_file.ca_chain.content)}"
    node_cert = "${indent(4, data.local_file.node_cert.content)}"
    node_priv_key = "${indent(4, data.local_file.node_priv_key.content)}"
    fqdn = "node1.example.local"
    consul_config = "${indent(4, data.template_file.node1_consul_config.rendered)}"
    consul_systemd_config = "${indent(4, data.local_file.node_consul_systemd_config.content)}"
    vault_config = "${indent(4, data.template_file.node1_vault_config.rendered)}"
    vault_systemd_config = "${indent(4, data.local_file.node_vault_systemd_config.content)}"
  }
}

resource "aws_instance" "node1" {
  ami = var.demo_ami
  instance_type = "t2.micro"
  availability_zone = "us-west-2a"
  iam_instance_profile = "${aws_iam_instance_profile.vault-kms-unseal.id}"
  network_interface {
    network_interface_id = aws_network_interface.node1.id
    device_index = 0
  }
  user_data = data.template_file.node1_cloud_init.rendered

  tags = {
    Name = "node1.example.local"
  }
}

resource "aws_network_interface" "node2" {
  subnet_id = aws_subnet.demo_subnet.id
  private_ips = ["10.0.1.11"]
  security_groups = [aws_security_group.demo-service.id]
  tags = {
    Name = "node2_network_interface"
  }
}

data "template_file" "node2_consul_config" {
  template = file("./configs/node-consul.hcl")
  vars = {
    node_name = "node2"
    node_ip = "10.0.1.11"
    node_a_name = "node1"
    node_b_name = "node3"
  }
}

data "template_file" "node2_vault_config" {
  template = file("./configs/node-vault-config.hcl")
  vars = {
    node_ip = "10.0.1.11"
    fqdn = "node2.example.local"
    region = var.region
    aws_kms_key = aws_kms_key.vault.id
  }
}

data "template_file" "node2_cloud_init" {
  template = file("./cloud-init/service-node-cloud-init")
  vars = {
    ssh_pub_key = "${data.local_file.ssh_pub_key.content}"
    ca_chain = "${indent(4, data.local_file.ca_chain.content)}"
    node_cert = "${indent(4, data.local_file.node_cert.content)}"
    node_priv_key = "${indent(4, data.local_file.node_priv_key.content)}"
    fqdn = "node2.example.local"
    consul_config = "${indent(4, data.template_file.node2_consul_config.rendered)}"
    consul_systemd_config = "${indent(4, data.local_file.node_consul_systemd_config.content)}"
    vault_config = "${indent(4, data.template_file.node2_vault_config.rendered)}"
    vault_systemd_config = "${indent(4, data.local_file.node_vault_systemd_config.content)}"
  }
}

resource "aws_instance" "node2" {
  ami = var.demo_ami
  instance_type = "t2.micro"
  availability_zone = "us-west-2a"
  iam_instance_profile = "${aws_iam_instance_profile.vault-kms-unseal.id}"
  network_interface {
    network_interface_id = aws_network_interface.node2.id
    device_index = 0
  }
  user_data = data.template_file.node2_cloud_init.rendered

  tags = {
    Name = "node2.example.local"
  }
}

resource "aws_network_interface" "node3" {
  subnet_id = aws_subnet.demo_subnet.id
  private_ips = ["10.0.1.12"]
  security_groups = [aws_security_group.demo-service.id]
  tags = {
    Name = "node3_network_interface"
  }
}

data "template_file" "node3_consul_config" {
  template = file("./configs/node-consul.hcl")
  vars = {
    node_name = "node3"
    node_ip = "10.0.1.12"
    node_a_name = "node1"
    node_b_name = "node2"
  }
}

data "template_file" "node3_vault_config" {
  template = file("./configs/node-vault-config.hcl")
  vars = {
    node_ip = "10.0.1.12"
    fqdn = "node3.example.local"
    region = var.region
    aws_kms_key = aws_kms_key.vault.id
  }
}

data "template_file" "node3_cloud_init" {
  template = file("./cloud-init/service-node-cloud-init")
  vars = {
    ssh_pub_key = "${data.local_file.ssh_pub_key.content}"
    ca_chain = "${indent(4, data.local_file.ca_chain.content)}"
    node_cert = "${indent(4, data.local_file.node_cert.content)}"
    node_priv_key = "${indent(4, data.local_file.node_priv_key.content)}"
    fqdn = "node3.example.local"
    consul_config = "${indent(4, data.template_file.node3_consul_config.rendered)}"
    consul_systemd_config = "${indent(4, data.local_file.node_consul_systemd_config.content)}"
    vault_config = "${indent(4, data.template_file.node3_vault_config.rendered)}"
    vault_systemd_config = "${indent(4, data.local_file.node_vault_systemd_config.content)}"
  }
}

resource "aws_instance" "node3" {
  ami = var.demo_ami
  instance_type = "t2.micro"
  availability_zone = "us-west-2a"
  iam_instance_profile = "${aws_iam_instance_profile.vault-kms-unseal.id}"
  network_interface {
    network_interface_id = aws_network_interface.node3.id
    device_index = 0
  }
  user_data = data.template_file.node3_cloud_init.rendered

  tags = {
    Name = "node3.example.local"
  }
}

output "node1_public_ip" {
  value = aws_instance.node1.public_ip
}

output "node2_public_ip" {
  value = aws_instance.node2.public_ip
}

output "node3_public_ip" {
  value = aws_instance.node3.public_ip
}

output "vpc_id" {
  value = aws_vpc.vpc.id
}

output "demo_subnet_id" {
  value = aws_subnet.demo_subnet.id
}
