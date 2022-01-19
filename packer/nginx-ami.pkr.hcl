# A Packer build template for building an AMI with Consul and Vault binaries already installed.
# consul-template version = 0.27.2 (current latest)

# Inspired from https://github.com/hashicorp/learn-terraform-provisioning/blob/packer/images/image.pkr.hcl

variable "region" {
  type = string
  default = "us-west-2"
}

locals { timestamp = regex_replace(timestamp(), "[- TZ:]", "") }

# AMI Ubuntu Server 20.04 LTS: ami-0892d3c7ee96c0bf7
source "amazon-ebs" "demo-web-service" {
  ami_name = "web-service-demo-${local.timestamp}"
  instance_type = "t2.micro"
  region = var.region
  source_ami = "ami-0892d3c7ee96c0bf7"
  ssh_username = "ubuntu"
}

build {
  sources = ["source.amazon-ebs.demo-web-service"]

  provisioner "file" {
    source = "./scripts/install-web-service"
    destination = "/tmp/install"
  }

  provisioner "shell" {
    inline = ["chmod a+x /tmp/install"]
  }

  provisioner "shell" {
    inline = ["/tmp/install --app consul-template --version 0.27.2"]
  }
}
