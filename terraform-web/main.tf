# Terraform configuration for deploying web service for demo
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "3.72.0"
    }
  }
}

variable "demo_web_ami" {
  description = "AMI to use for web demo"
  default = "ami-04dbb6dd2b4542a4f"
  type = string
}

variable "region" {
  description = "AWS Region to create resources in"
  default = "us-west-2"
  type = string
}

provider "aws" {
  region = var.region
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
data "local_file" "vault_token_for_demo" {
  filename = "./.vault_token_for_demo"
}

data "local_file" "ca_chain" {
  filename = "../tls/root/ca/intermediate/certs/ca-chain.cert.pem"
}

data "local_file" "node_cert" {
  filename = "../tls/root/ca/intermediate/certs/node.example.local.cert.pem"
}

data "local_file" "node_priv_key" {
  filename = "../tls/root/ca/intermediate/private/node.example.local.key.pem"
}

data "template_file" "web_consul_template_config" {
  template = file("./configs/web-consul-template-config.hcl")
  vars = {
    vault_addr = "node1.example.local"
    fqdn = "web.example.local"
  }
}

data "local_file" "web_consul_template_systemd_config" {
  filename = "./configs/web-consul-template-systemd-config"
}

data "local_file" "web_default_index_html" {
  filename = "./configs/index.html"
}

data "template_file" "nginx-config" {
  template = file("./configs/nginx-default")
  vars = {
    fqdn = "web.example.local"
  }
}

#### Deploy NGINX web instance ####
data "template_file" "web_cloud_init" {
  template = file("./cloud-init/service-web-cloud-init")
  vars = {
    ssh_pub_key = "${data.local_file.ssh_pub_key.content}"
    ca_chain = "${indent(4, data.local_file.ca_chain.content)}"
    node_cert = "${indent(4, data.local_file.node_cert.content)}"
    node_priv_key = "${indent(4, data.local_file.node_priv_key.content)}"
    fqdn = "web.example.local"
    vault_addr = "node1.example.local"
    consul_template_config = "${indent(4, data.template_file.web_consul_template_config.rendered)}"
    consul_template_systemd_config = "${indent(4, data.local_file.web_consul_template_systemd_config.content)}"
    nginx_default = "${indent(4, data.template_file.nginx-config.rendered)}"
    vault_token = "${indent(4, data.local_file.vault_token_for_demo.content)}"
    demo_index_html = "${indent(4, data.local_file.web_default_index_html.content)}"    
  }
}

# Very fragile at the moment. Need to use existing resources dynammically
variable "demo_subnet_id" {
  description = "demo subnet"
  default = "subnet-0d1342e7c6cf6b3af"
  type = string
}

variable "vpc_id" {
  description = "demo vpc"
  default = "vpc-053b911415ea9db28"
}

# Create NGNIX security group
resource "aws_security_group" "demo-web-service" {
  name = "demo-web-service"
  description = "Allow HTTPS access to NGINX"
  vpc_id = var.vpc_id

  ingress {
    description = "Allow SSH"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "demo-web-security-group-1"
  }
}

resource "aws_network_interface" "web" {
  subnet_id = var.demo_subnet_id
  private_ips = ["10.0.1.20"]
  security_groups = [aws_security_group.demo-web-service.id]
  tags = {
    Name = "web_network_interface"
  }
}

resource "aws_instance" "web" {
  ami = var.demo_web_ami
  instance_type = "t2.micro"
  availability_zone = "us-west-2a"
  network_interface {
    network_interface_id = aws_network_interface.web.id
    device_index = 0
  }
  user_data = data.template_file.web_cloud_init.rendered

  tags = {
    Name = "web.example.local"
  }
}

output "web_public_ip" {
  value = aws_instance.web.public_ip
}
