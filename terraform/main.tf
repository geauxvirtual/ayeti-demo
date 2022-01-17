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
     from_port = 8201
     to_port = 8201
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
    Name = "demo-vault-conusl-security-group-1"
  }
}

# Create NGNIX security group
resource "aws_security_group" "demo-web-service" {
  name = "demo-web-service"
  description = "Allow HTTPS access to NGINX"
  vpc_id = aws_vpc.vpc.id
  
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

