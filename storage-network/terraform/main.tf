terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

resource "aws_vpc" "aws_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "aws_igw" {
  vpc_id = aws_vpc.aws_vpc.id

  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

resource "aws_route_table" "aws_public_rt" {
  depends_on = [
    aws_internet_gateway.aws_igw,
  ]

  vpc_id = aws_vpc.aws_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.aws_igw.id
  }

  tags = {
    Name = "${var.name_prefix}-public-rt"
  }
}

resource "aws_subnet" "aws_subnet_1" {
  vpc_id     = aws_vpc.aws_vpc.id
  availability_zone = "us-east-1c"
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "${var.name_prefix}-subnet-1"
  }
}

resource "aws_subnet" "aws_subnet_2" {
  vpc_id     = aws_vpc.aws_vpc.id
  availability_zone = "us-east-1c"
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "${var.name_prefix}-subnet-2"
  }
}

resource "aws_route_table_association" "aws_subnet_1_rt_association" {
  depends_on = [
    aws_subnet.aws_subnet_1,
    aws_route_table.aws_public_rt
  ]

  subnet_id      = aws_subnet.aws_subnet_1.id
  route_table_id = aws_route_table.aws_public_rt.id
}

resource "aws_route_table_association" "aws_subnet_2_rt_association" {
  depends_on = [
    aws_subnet.aws_subnet_2,
    aws_route_table.aws_public_rt
  ]

  subnet_id      = aws_subnet.aws_subnet_2.id
  route_table_id = aws_route_table.aws_public_rt.id
}

resource "aws_security_group" "aws_secgrp" {
  name        = "${var.name_prefix}-secgrp"
  description = "Allow all inbound traffic"
  vpc_id      = aws_vpc.aws_vpc.id

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow all ports"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-secgrp"
  }
}

locals {
  k8s_distro_version = "v1.22.9+k3s1"
}

resource "random_string" "random_suffix" {
  length           = 8
  special          = false
  lower            = true
  upper            = false
}

resource "random_password" "cluster_secret" {
  length = 64
  special = false
}

resource "aws_key_pair" "aws_pair_key" {
  key_name   = format("%s_%s", "aws_key_pair", random_string.random_suffix.id)
  public_key = file(var.aws_ssh_public_key_file_path)
}

resource "aws_instance" "aws_instance_controlplane" {
  depends_on = [
    aws_subnet.aws_subnet_1,
    aws_subnet.aws_subnet_2,
  ]

  ami           = data.aws_ami.aws_ami_ubuntu.id
  instance_type = "t2.xlarge"

  network_interface {
    network_interface_id = aws_network_interface.controlplane_eth0.id
    device_index         = 0
  }

  root_block_device {
    delete_on_termination = true
    volume_size = 40
  }

  key_name = aws_key_pair.aws_pair_key.key_name
  user_data = data.template_file.provision_k3s_server.rendered

  tags = {
    Name = "${var.name_prefix}-controlplane"
  }
}

resource "aws_network_interface" "controlplane_eth0" {
  subnet_id   = aws_subnet.aws_subnet_1.id
  security_groups = [aws_security_group.aws_secgrp.id]

  tags = {
    Name = "${var.name_prefix}-controlplane-eth0"
  }
}

resource "aws_network_interface" "controlplane_eth1" {
  subnet_id   = aws_subnet.aws_subnet_2.id
  security_groups = [aws_security_group.aws_secgrp.id]

  attachment {
    instance     = aws_instance.aws_instance_controlplane.id
    device_index = 1
  }

  tags = {
    Name = "${var.name_prefix}-controlplane-eth1"
  }
}

resource "aws_instance" "aws_instance_worker1" {
  depends_on = [
    aws_subnet.aws_subnet_1,
    aws_subnet.aws_subnet_2,
  ]

  ami           = data.aws_ami.aws_ami_ubuntu.id
  instance_type = "t2.xlarge"

  network_interface {
    network_interface_id = aws_network_interface.worker1_eth0.id
    device_index         = 0
  }

  root_block_device {
    delete_on_termination = true
    volume_size = 40
  }

  key_name = aws_key_pair.aws_pair_key.key_name
  user_data = data.template_file.provision_k3s_agent.rendered

  tags = {
    Name = "${var.name_prefix}-worker1"
  }
}

resource "aws_network_interface" "worker1_eth0" {
  subnet_id   = aws_subnet.aws_subnet_1.id
  security_groups = [aws_security_group.aws_secgrp.id]

  tags = {
    Name = "${var.name_prefix}-worker1-eth0"
  }
}

resource "aws_network_interface" "worker1_eth1" {
  subnet_id   = aws_subnet.aws_subnet_2.id
  security_groups = [aws_security_group.aws_secgrp.id]

  attachment {
    instance     = aws_instance.aws_instance_worker1.id
    device_index = 1
  }

  tags = {
    Name = "${var.name_prefix}-worker1-eth1"
  }
}

resource "aws_instance" "aws_instance_worker2" {
  depends_on = [
    aws_subnet.aws_subnet_1,
    aws_subnet.aws_subnet_2,
  ]

  ami           = data.aws_ami.aws_ami_ubuntu.id
  instance_type = "t2.xlarge"

  network_interface {
    network_interface_id = aws_network_interface.worker2_eth0.id
    device_index         = 0
  }

  root_block_device {
    delete_on_termination = true
    volume_size = 40
  }

  key_name = aws_key_pair.aws_pair_key.key_name
  user_data = data.template_file.provision_k3s_agent.rendered

  tags = {
    Name = "${var.name_prefix}-worker2"
  }
}

resource "aws_network_interface" "worker2_eth0" {
  subnet_id   = aws_subnet.aws_subnet_1.id
  security_groups = [aws_security_group.aws_secgrp.id]

  tags = {
    Name = "${var.name_prefix}-worker2-eth0"
  }
}

resource "aws_network_interface" "worker2_eth1" {
  subnet_id   = aws_subnet.aws_subnet_2.id
  security_groups = [aws_security_group.aws_secgrp.id]

  attachment {
    instance     = aws_instance.aws_instance_worker2.id
    device_index = 1
  }

  tags = {
    Name = "${var.name_prefix}-worker2-eth1"
  }
}

resource "aws_eip" "aws_eip_controlplane" {
  vpc      = true
}

resource "aws_eip_association" "aws_eip_assoc_controlplane" {
  depends_on = [
    aws_instance.aws_instance_controlplane,
    aws_eip.aws_eip_controlplane
  ]

  network_interface_id    = aws_network_interface.controlplane_eth0.id
  allocation_id = aws_eip.aws_eip_controlplane.id
}

resource "aws_eip" "aws_eip_worker1" {
  vpc      = true
}

resource "aws_eip_association" "aws_eip_assoc_worker1" {
  depends_on = [
    aws_instance.aws_instance_worker1,
    aws_eip.aws_eip_worker1
  ]

  network_interface_id    = aws_network_interface.worker1_eth0.id
  allocation_id = aws_eip.aws_eip_worker1.id
}

resource "aws_eip" "aws_eip_worker2" {
  vpc      = true
}

resource "aws_eip_association" "aws_eip_assoc_worker2" {
  depends_on = [
    aws_instance.aws_instance_worker2,
    aws_eip.aws_eip_worker2
  ]

  network_interface_id    = aws_network_interface.worker2_eth0.id
  allocation_id = aws_eip.aws_eip_worker2.id
}