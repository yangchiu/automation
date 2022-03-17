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

locals {
  instance_type = var.arch == "amd64" ? "t2.xlarge" : "a1.xlarge"
  k8s_distro_version = var.k8s_distro_name == "k3s" ? "v1.23.1+k3s2" : (var.k8s_distro_name == "rke" ? "v1.22.5-rancher1-1" : "v1.23.3+rke2r1")
}

# Create a random string suffix for instance names
resource "random_string" "random_suffix" {
  length           = 8
  special          = false
  lower            = true
  upper            = false
}

# Create a VPC
resource "aws_vpc" "aws_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}

# Create internet gateway
resource "aws_internet_gateway" "aws_igw" {
  vpc_id = aws_vpc.aws_vpc.id

  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

# Create controlplane security group
resource "aws_security_group" "aws_secgrp_controlplane" {
  name        = "${var.name_prefix}-secgrp-controlplane"
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
    description = "Allow k8s API server port"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow rke2 port"
    from_port   = 9345
    to_port     = 9345
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow k8s API server port"
    from_port   = 2379
    to_port     = 2379
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow node port"
    from_port   = 30007
    to_port     = 30007
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow web"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow tls"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow web demo"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow web demo 2"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow UDP connection for longhorn-webhooks"
    from_port   = 0
    to_port     = 65535
    protocol    = "udp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-secgrp-controlplane"
  }
}

# Create worker security group
resource "aws_security_group" "aws_secgrp_worker" {
  name        = "${var.name_prefix}-secgrp-worker"
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
    description = "Allow web"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow tls"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow web demo"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow web demo 2"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow All Traffic from VPC CIDR block"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.aws_vpc.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-secgrp-worker"
  }
}

# Create Public subnet
resource "aws_subnet" "aws_public_subnet" {
  vpc_id     = aws_vpc.aws_vpc.id
  availability_zone = var.aws_availability_zone
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "${var.name_prefix}-public-subnet"
  }
}

# Create private subnet
resource "aws_subnet" "aws_private_subnet" {
  vpc_id     = aws_vpc.aws_vpc.id
  availability_zone = var.aws_availability_zone
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "${var.name_prefix}-private-subnet"
  }
}

# Create route table for public subnets
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

# Create route table for private subnets
resource "aws_route_table" "aws_private_rt" {
  depends_on = [
    aws_internet_gateway.aws_igw,
  ]

  vpc_id = aws_vpc.aws_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.aws_igw.id
  }

  tags = {
    Name = "${var.name_prefix}-private-rt"
  }
}

# Associate public subnet to public route table
resource "aws_route_table_association" "aws_public_subnet_rt_association" {
  depends_on = [
    aws_subnet.aws_public_subnet,
    aws_route_table.aws_public_rt
  ]

  subnet_id      = aws_subnet.aws_public_subnet.id
  route_table_id = aws_route_table.aws_public_rt.id
}

# Associate private subnet to private route table
resource "aws_route_table_association" "aws_private_subnet_rt_association" {
  depends_on = [
    aws_subnet.aws_private_subnet,
    aws_route_table.aws_private_rt
  ]

  subnet_id      = aws_subnet.aws_private_subnet.id
  route_table_id = aws_route_table.aws_private_rt.id
}

# Create AWS key pair
resource "aws_key_pair" "aws_pair_key" {
  key_name   = format("%s_%s", "aws_key_pair", "${random_string.random_suffix.id}")
  public_key = file(var.aws_ssh_public_key_file_path)
}

# Create cluster secret (used for k3s or rke2 only)
resource "random_password" "cluster_secret" {
  length = var.k8s_distro_name == "rke" ? 0 : 64
  special = false
}

# Create controlplane instances
resource "aws_instance" "aws_instance_controlplane" {
 depends_on = [
    aws_subnet.aws_public_subnet,
  ]

  count = var.aws_instance_count_controlplane

  availability_zone = var.aws_availability_zone

  ami           = data.aws_ami.aws_ami_ubuntu.id
  instance_type = local.instance_type

  subnet_id = aws_subnet.aws_public_subnet.id
  vpc_security_group_ids = [
    aws_security_group.aws_secgrp_controlplane.id
  ]

  associate_public_ip_address = true

  root_block_device {
    delete_on_termination = true
    volume_size = var.aws_instance_root_block_device_size_controlplane
  }

  key_name = aws_key_pair.aws_pair_key.key_name
  user_data = var.k8s_distro_name == "k3s" ? data.template_file.provision_k3s_server.rendered : (var.k8s_distro_name == "rke2" ? data.template_file.provision_rke2_server.rendered : file("${path.module}/user-data-scripts/provision_rke.sh"))

  tags = {
    Name = "${var.name_prefix}-controlplane-${count.index}"
  }
}

resource "aws_eip" "aws_eip_controlplane" {
  count    = var.aws_instance_count_controlplane
  vpc      = true
}

# Associate every EIP with controlplane instance
resource "aws_eip_association" "aws_eip_assoc" {
  depends_on = [
    aws_instance.aws_instance_controlplane,
    aws_eip.aws_eip_controlplane
  ]

  count    = var.aws_instance_count_controlplane

  instance_id   = element(aws_instance.aws_instance_controlplane, count.index).id
  allocation_id = element(aws_eip.aws_eip_controlplane, count.index).id
}

# Create worker instances
resource "aws_instance" "aws_instance_worker" {
  depends_on = [
    aws_internet_gateway.aws_igw,
    aws_subnet.aws_private_subnet,
    aws_instance.aws_instance_controlplane
  ]

  count = var.aws_instance_count_worker

  availability_zone = var.aws_availability_zone

  ami           = data.aws_ami.aws_ami_ubuntu.id
  instance_type = local.instance_type

  subnet_id = aws_subnet.aws_private_subnet.id
  vpc_security_group_ids = [
    aws_security_group.aws_secgrp_worker.id
  ]

  associate_public_ip_address = true

  root_block_device {
    delete_on_termination = true
    volume_size = var.aws_instance_root_block_device_size_worker
  }

  key_name = aws_key_pair.aws_pair_key.key_name

  user_data = var.k8s_distro_name == "k3s" ? data.template_file.provision_k3s_agent.rendered : (var.k8s_distro_name == "rke2" ? data.template_file.provision_rke2_agent.rendered : file("${path.module}/user-data-scripts/provision_rke.sh"))

  tags = {
    Name = "${var.name_prefix}-worker-${count.index}"
  }
}

# wait for docker to start on controlplane instances (for rke on rke only)
resource "null_resource" "wait_for_docker_start_controlplane" {

  depends_on = [
    aws_instance.aws_instance_controlplane,
    aws_instance.aws_instance_worker,
    aws_eip.aws_eip_controlplane,
    aws_eip_association.aws_eip_assoc
  ]

  count = var.aws_instance_count_controlplane

  provisioner "remote-exec" {

    inline = var.k8s_distro_name == "rke" ? ["until( systemctl is-active docker.service ); do echo \"waiting for docker to start \"; sleep 2; done"] : null

    connection {
      type     = "ssh"
      user     = "ubuntu"
      host     = element(aws_eip.aws_eip_controlplane, count.index).public_ip
      private_key = file(var.aws_ssh_private_key_file_path)
    }
  }
}

# wait for docker to start on worker instances (for rke on rke only)
resource "null_resource" "wait_for_docker_start_worker" {

  depends_on = [
    aws_instance.aws_instance_controlplane,
    aws_instance.aws_instance_worker,
    aws_eip.aws_eip_controlplane,
    aws_eip_association.aws_eip_assoc
  ]

  count = var.aws_instance_count_worker

  provisioner "remote-exec" {
    inline = var.k8s_distro_name == "rke" ? ["until( systemctl is-active docker.service ); do echo \"waiting for docker to start \"; sleep 2; done"] : null

    connection {
      type     = "ssh"
      user     = "ubuntu"
      host     = element(aws_instance.aws_instance_worker, count.index).private_ip
      private_key = file(var.aws_ssh_private_key_file_path)
      bastion_user     = "ubuntu"
      bastion_host     = aws_eip.aws_eip_controlplane[0].public_ip
      bastion_private_key = file(var.aws_ssh_private_key_file_path)
    }
  }
}

# Download KUBECONFIG file (for k3s k3s only)
resource "null_resource" "rsync_kubeconfig_file" {

  count = var.k8s_distro_name == "k3s" ? 1 : 0

  depends_on = [
    aws_instance.aws_instance_controlplane,
    aws_eip.aws_eip_controlplane,
    aws_eip_association.aws_eip_assoc
  ]

  provisioner "remote-exec" {
    inline = var.k8s_distro_name == "k3s" ? ["until([ -f /etc/rancher/k3s/k3s.yaml ] && [ `sudo /usr/local/bin/kubectl get node -o jsonpath='{.items[*].status.conditions}'  | jq '.[] | select(.type  == \"Ready\").status' | grep -ci true` -eq 4 ]); do echo \"waiting for k3s cluster nodes to be running\"; sleep 2; done"] : null


    connection {
      type     = "ssh"
      user     = "ubuntu"
      host     = aws_eip.aws_eip_controlplane[0].public_ip
      private_key = file(var.aws_ssh_private_key_file_path)
    }
  }

  provisioner "local-exec" {
    command = var.k8s_distro_name == "k3s" ? "rsync -aPvz --rsync-path=\"sudo rsync\" -e \"ssh -o StrictHostKeyChecking=no -l ubuntu -i ${var.aws_ssh_private_key_file_path}\" ${aws_eip.aws_eip_controlplane[0].public_ip}:/etc/rancher/k3s/k3s.yaml .  && sed -i 's#https://127.0.0.1:6443#https://${aws_eip.aws_eip_controlplane[0].public_ip}:6443#' k3s.yaml"  : "echo \"rke ... skipping\""
  }
}

# Download KUBECONFIG file for rke2
resource "null_resource" "rsync_kubeconfig_file_rke2" {

  count = var.k8s_distro_name == "rke2" ? 1 : 0

  depends_on = [
    aws_instance.aws_instance_controlplane,
    aws_eip.aws_eip_controlplane,
    aws_eip_association.aws_eip_assoc
  ]

  provisioner "remote-exec" {
    inline = var.k8s_distro_name == "rke2" ? ["until([ -f /etc/rancher/rke2/rke2.yaml ] && [ `sudo KUBECONFIG=/etc/rancher/rke2/rke2.yaml /var/lib/rancher/rke2/bin/kubectl get node -o jsonpath='{.items[*].status.conditions}'  | jq '.[] | select(.type  == \"Ready\").status' | grep -ci true` -eq $((${var.aws_instance_count_controlplane} + ${var.aws_instance_count_worker})) ]); do echo \"waiting for rke2 cluster nodes to be running\"; sleep 2; done"] : null


    connection {
      type     = "ssh"
      user     = "ubuntu"
      host     = aws_eip.aws_eip_controlplane[0].public_ip
      private_key = file(var.aws_ssh_private_key_file_path)
    }
  }

  provisioner "local-exec" {
    command = var.k8s_distro_name == "rke2" ? "rsync -aPvz --rsync-path=\"sudo rsync\" -e \"ssh -o StrictHostKeyChecking=no -l ubuntu -i ${var.aws_ssh_private_key_file_path}\" ${aws_eip.aws_eip_controlplane[0].public_ip}:/etc/rancher/rke2/rke2.yaml .  && sed -i 's#https://127.0.0.1:6443#https://${aws_eip.aws_eip_controlplane[0].public_ip}:6443#' rke2.yaml" : "echo \"not rke2 ... skipping\""
  }
}

# cluster 2 start

# Create cluster secret (used for k3s or rke2 only)
resource "random_password" "cluster2_secret" {
  length = var.k8s_distro_name == "rke" ? 0 : 64
  special = false
}

# Create controlplane instances
resource "aws_instance" "aws_instance_cluster2_controlplane" {
 depends_on = [
    aws_subnet.aws_public_subnet,
  ]

  count = var.aws_instance_count_controlplane

  availability_zone = var.aws_availability_zone

  ami           = data.aws_ami.aws_ami_ubuntu.id
  instance_type = local.instance_type

  subnet_id = aws_subnet.aws_public_subnet.id
  vpc_security_group_ids = [
    aws_security_group.aws_secgrp_controlplane.id
  ]

  associate_public_ip_address = true

  root_block_device {
    delete_on_termination = true
    volume_size = var.aws_instance_root_block_device_size_controlplane
  }

  key_name = aws_key_pair.aws_pair_key.key_name
  user_data = var.k8s_distro_name == "k3s" ? data.template_file.provision_k3s_cluster2_server.rendered : (var.k8s_distro_name == "rke2" ? data.template_file.provision_rke2_cluster2_server.rendered : file("${path.module}/user-data-scripts/provision_rke.sh"))

  tags = {
    Name = "${var.name_prefix}-cluster2-controlplane-${count.index}"
  }
}

resource "aws_eip" "aws_eip_cluster2_controlplane" {
  count    = var.aws_instance_count_controlplane
  vpc      = true
}

# Associate every EIP with controlplane instance
resource "aws_eip_association" "aws_eip_assoc_cluster2" {
  depends_on = [
    aws_instance.aws_instance_cluster2_controlplane,
    aws_eip.aws_eip_cluster2_controlplane
  ]

  count    = var.aws_instance_count_controlplane

  instance_id   = element(aws_instance.aws_instance_cluster2_controlplane, count.index).id
  allocation_id = element(aws_eip.aws_eip_cluster2_controlplane, count.index).id
}

# Create worker instances
resource "aws_instance" "aws_instance_cluster2_worker" {
  depends_on = [
    aws_internet_gateway.aws_igw,
    aws_subnet.aws_private_subnet,
    aws_instance.aws_instance_cluster2_controlplane
  ]

  count = var.aws_instance_count_worker

  availability_zone = var.aws_availability_zone

  ami           = data.aws_ami.aws_ami_ubuntu.id
  instance_type = local.instance_type

  subnet_id = aws_subnet.aws_private_subnet.id
  vpc_security_group_ids = [
    aws_security_group.aws_secgrp_worker.id
  ]

  associate_public_ip_address = true

  root_block_device {
    delete_on_termination = true
    volume_size = var.aws_instance_root_block_device_size_worker
  }

  key_name = aws_key_pair.aws_pair_key.key_name

  user_data = var.k8s_distro_name == "k3s" ? data.template_file.provision_k3s_cluster2_agent.rendered : (var.k8s_distro_name == "rke2" ? data.template_file.provision_rke2_cluster2_agent.rendered : file("${path.module}/user-data-scripts/provision_rke.sh"))

  tags = {
    Name = "${var.name_prefix}-cluster2-worker-${count.index}"
  }
}

# wait for docker to start on controlplane instances (for rke on rke only)
resource "null_resource" "wait_for_docker_start_controlplane_cluster2" {

  depends_on = [
    aws_instance.aws_instance_cluster2_controlplane,
    aws_instance.aws_instance_cluster2_worker,
    aws_eip.aws_eip_cluster2_controlplane,
    aws_eip_association.aws_eip_assoc_cluster2
  ]

  count = var.aws_instance_count_controlplane

  provisioner "remote-exec" {

    inline = var.k8s_distro_name == "rke" ? ["until( systemctl is-active docker.service ); do echo \"waiting for docker to start \"; sleep 2; done"] : null

    connection {
      type     = "ssh"
      user     = "ubuntu"
      host     = element(aws_eip.aws_eip_cluster2_controlplane, count.index).public_ip
      private_key = file(var.aws_ssh_private_key_file_path)
    }
  }
}

# wait for docker to start on worker instances (for rke on rke only)
resource "null_resource" "wait_for_docker_start_worker_cluster2" {

  depends_on = [
    aws_instance.aws_instance_cluster2_controlplane,
    aws_instance.aws_instance_cluster2_worker,
    aws_eip.aws_eip_cluster2_controlplane,
    aws_eip_association.aws_eip_assoc_cluster2
  ]

  count = var.aws_instance_count_worker

  provisioner "remote-exec" {
    inline = var.k8s_distro_name == "rke" ? ["until( systemctl is-active docker.service ); do echo \"waiting for docker to start \"; sleep 2; done"] : null

    connection {
      type     = "ssh"
      user     = "ubuntu"
      host     = element(aws_instance.aws_instance_cluster2_worker, count.index).private_ip
      private_key = file(var.aws_ssh_private_key_file_path)
      bastion_user     = "ubuntu"
      bastion_host     = aws_eip.aws_eip_cluster2_controlplane[0].public_ip
      bastion_private_key = file(var.aws_ssh_private_key_file_path)
    }
  }
}

# Download KUBECONFIG file (for k3s k3s only)
resource "null_resource" "rsync_kubeconfig_file_cluster2" {

  count = var.k8s_distro_name == "k3s" ? 1 : 0

  depends_on = [
    aws_instance.aws_instance_cluster2_controlplane,
    aws_eip.aws_eip_cluster2_controlplane,
    aws_eip_association.aws_eip_assoc_cluster2
  ]

  provisioner "remote-exec" {
    inline = var.k8s_distro_name == "k3s" ? ["until([ -f /etc/rancher/k3s/k3s.yaml ] && [ `sudo /usr/local/bin/kubectl get node -o jsonpath='{.items[*].status.conditions}'  | jq '.[] | select(.type  == \"Ready\").status' | grep -ci true` -eq 4 ]); do echo \"waiting for k3s cluster nodes to be running\"; sleep 2; done"] : null


    connection {
      type     = "ssh"
      user     = "ubuntu"
      host     = aws_eip.aws_eip_cluster2_controlplane[0].public_ip
      private_key = file(var.aws_ssh_private_key_file_path)
    }
  }

  provisioner "local-exec" {
    command = var.k8s_distro_name == "k3s" ? "rsync -aPvz --rsync-path=\"sudo rsync\" -e \"ssh -o StrictHostKeyChecking=no -l ubuntu -i ${var.aws_ssh_private_key_file_path}\" ${aws_eip.aws_eip_cluster2_controlplane[0].public_ip}:/etc/rancher/k3s/k3s.yaml k3s_cluster2.yaml  && sed -i 's#https://127.0.0.1:6443#https://${aws_eip.aws_eip_cluster2_controlplane[0].public_ip}:6443#' k3s_cluster2.yaml"  : "echo \"rke ... skipping\""
  }
}

# Download KUBECONFIG file for rke2
resource "null_resource" "rsync_kubeconfig_file_rke2_cluster2" {

  count = var.k8s_distro_name == "rke2" ? 1 : 0

  depends_on = [
    aws_instance.aws_instance_cluster2_controlplane,
    aws_eip.aws_eip_cluster2_controlplane,
    aws_eip_association.aws_eip_assoc_cluster2
  ]

  provisioner "remote-exec" {
    inline = var.k8s_distro_name == "rke2" ? ["until([ -f /etc/rancher/rke2/rke2.yaml ] && [ `sudo KUBECONFIG=/etc/rancher/rke2/rke2.yaml /var/lib/rancher/rke2/bin/kubectl get node -o jsonpath='{.items[*].status.conditions}'  | jq '.[] | select(.type  == \"Ready\").status' | grep -ci true` -eq $((${var.aws_instance_count_controlplane} + ${var.aws_instance_count_worker})) ]); do echo \"waiting for rke2 cluster nodes to be running\"; sleep 2; done"] : null


    connection {
      type     = "ssh"
      user     = "ubuntu"
      host     = aws_eip.aws_eip_cluster2_controlplane[0].public_ip
      private_key = file(var.aws_ssh_private_key_file_path)
    }
  }

  provisioner "local-exec" {
    command = var.k8s_distro_name == "rke2" ? "rsync -aPvz --rsync-path=\"sudo rsync\" -e \"ssh -o StrictHostKeyChecking=no -l ubuntu -i ${var.aws_ssh_private_key_file_path}\" ${aws_eip.aws_eip_cluster2_controlplane[0].public_ip}:/etc/rancher/rke2/rke2.yaml rke2_cluster2.yaml  && sed -i 's#https://127.0.0.1:6443#https://${aws_eip.aws_eip_cluster2_controlplane[0].public_ip}:6443#' rke2_cluster2.yaml" : "echo \"not rke2 ... skipping\""
  }
}
