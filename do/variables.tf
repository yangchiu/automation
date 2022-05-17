variable "do_token" {
  type = string
}

variable "controlplane_count" {
  type = number
  default = 1
}

variable "worker_count" {
  type = number
  default = 1
}

variable "region" {
  type = string
  default = "sgp1"
}

variable "instance_size" {
  type = string
  default = "s-2vcpu-4gb"
}

variable "ssh_public_key_path" {
  type = string
  default = "~/.ssh/id_rsa.pub"
}

variable "ssh_private_key_path" {
  type = string
  default = "~/.ssh/id_rsa"
}

variable "k8s_distro_version" {
  type = string
  default = "v1.23.1+k3s2"
}

variable "rancher_domain_name" {
  type = string
}

variable "rancher_bootstrap_password" {
  type = string
}