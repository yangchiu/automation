variable "name_prefix" {
  type    = string
  default = "yang"
}

variable "aws_access_key" {
  type        = string
  description = "AWS ACCESS_KEY"
}

variable "aws_secret_key" {
  type        = string
  description = "AWS SECRET_KEY"
}

variable "aws_region" {
  type        = string
  default     = "us-east-1"
}

variable "aws_availability_zone" {
  type        = string
  default     = "us-east-1c"
}

variable "arch" {
  type        = string
  description = "available values (amd64, arm64)"
}

variable "os_distro_version" {
  type        = string
  default     = "8.3"
}

variable "aws_ami_rhel_account_number" {
  type        = string
  default     = "309956199498"
}

variable "aws_instance_count_controlplane" {
  type        = number
  default     = 1
}

variable "aws_instance_count_worker" {
  type        = number
  default     = 3
}

variable "aws_instance_root_block_device_size_controlplane" {
  type        = number
  default     = 40
}

variable "aws_ssh_public_key_file_path" {
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "aws_ssh_private_key_file_path" {
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "aws_instance_root_block_device_size_worker" {
  type        = number
  default     = 40
}

variable "k8s_distro_name" {
  type        = string
  default     = "k3s"
  description = "kubernetes distro version to install [rke, k3s]  (default: k3s)"
}

variable "selinux_mode" {
  type        = string
  default     = "enforcing"
  description = "SELINUX mode [permissive | enforcing] (available only for CentOS, RedHat and RockyLinux)"
}
