# Query AWS for Ubuntu AMI
data "aws_ami" "aws_ami_ubuntu" {
  most_recent      = true
  owners           = [var.aws_ami_ubuntu_account_number]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu*${var.os_distro_version}-${var.arch}-server-*"]
  }
}

# Generate template file for k3s server
data "template_file" "provision_k3s_server" {
  template = file("${path.module}/user-data-scripts/provision_k3s_server.sh.tpl")
  vars = {
    k3s_cluster_secret = random_password.cluster_secret.result
    k3s_server_public_ip = aws_eip.aws_eip_controlplane.public_ip
    k3s_version =  local.k8s_distro_version
  }
}

# Generate template file for k3s agent
data "template_file" "provision_k3s_agent" {
  template = file("${path.module}/user-data-scripts/provision_k3s_agent.sh.tpl")
  vars = {
    k3s_server_url = "https://${aws_eip.aws_eip_controlplane.public_ip}:6443"
    k3s_cluster_secret = random_password.cluster_secret.result
    k3s_version =  local.k8s_distro_version
  }
}