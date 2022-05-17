terraform {
  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

resource "random_password" "cluster_secret" {
  length = 64
}

locals {
  server_droplet_tag = "k3s_server"
}

resource "digitalocean_ssh_key" "ssh_public_key" {
  name  = "yang-public-ssh-key"
  public_key = file(var.ssh_public_key_path)
}

resource "digitalocean_droplet" "controlplane" {
  count     = var.controlplane_count
  image     = "ubuntu-20-04-x64"
  name      = "yang-controlplane"
  tags      = [
    local.server_droplet_tag
  ]
  region    = var.region
  size      = var.instance_size
  ssh_keys  = [
    digitalocean_ssh_key.ssh_public_key.fingerprint
  ]
  user_data = data.template_file.k3s_server.rendered

  depends_on = [
    digitalocean_loadbalancer.loadbalancer
  ]
}

resource "digitalocean_loadbalancer" "loadbalancer" {
  name   = "yang-loadbalancer"
  region = var.region

  forwarding_rule {
    tls_passthrough = true
    entry_port      = 6443
    entry_protocol  = "https"

    target_port     = 6443
    target_protocol = "https"
  }

  forwarding_rule {
    entry_port      = 22
    entry_protocol  = "tcp"

    target_port     = 22
    target_protocol = "tcp"
  }

  forwarding_rule {
    entry_port      = 80
    entry_protocol  = "http"

    target_port     = 80
    target_protocol = "http"
  }

  forwarding_rule {
    tls_passthrough = true
    entry_port      = 443
    entry_protocol  = "https"

    target_port     = 443
    target_protocol = "https"
  }

  healthcheck {
    port     = 6443
    protocol = "tcp"
  }

  droplet_tag = local.server_droplet_tag
}

resource "digitalocean_droplet" "worker" {
  count     = var.worker_count
  image     = "ubuntu-20-04-x64"
  name      = "yang-worker"
  region    = "sgp1"
  size      = "s-2vcpu-4gb"
  ssh_keys  = [
    digitalocean_ssh_key.ssh_public_key.fingerprint
  ]
  user_data = data.template_file.k3s_agent.rendered

  depends_on = [
    digitalocean_droplet.controlplane
  ]
}

# download KUBECONFIG file for k3s
resource "null_resource" "rsync_kubeconfig_file" {

  depends_on = [
    digitalocean_droplet.controlplane,
    digitalocean_loadbalancer.loadbalancer,
    digitalocean_droplet.worker
  ]

  provisioner "remote-exec" {
    inline = [
      "cloud-init status --wait",
      "if [ \"`cloud-init status | grep error`\" ]; then cat /var/log/cloud-init-output.log; fi",
      "until([ -f /etc/rancher/k3s/k3s.yaml ] && [ `sudo /usr/local/bin/kubectl get node -o jsonpath='{.items[*].status.conditions}'  | jq '.[] | select(.type  == \"Ready\").status' | grep -ci true` -eq $((${var.controlplane_count} + ${var.worker_count})) ]); do echo \"waiting for k3s cluster nodes to be running\"; sleep 2; done"
    ]

    connection {
      type     = "ssh"
      user     = "root"
      host     = digitalocean_loadbalancer.loadbalancer.ip
      private_key = file(var.ssh_private_key_path)
    }
  }

  provisioner "local-exec" {
    command = "rsync -aPvz --rsync-path=\"sudo rsync\" -e \"ssh -o StrictHostKeyChecking=no -l root -i ${var.ssh_private_key_path}\" ${digitalocean_loadbalancer.loadbalancer.ip}:/etc/rancher/k3s/k3s.yaml .  && sed -i 's#https://127.0.0.1:6443#https://${digitalocean_loadbalancer.loadbalancer.ip}:6443#' k3s.yaml"
  }
}

# setup rancher
resource "null_resource" "setup_rancher" {

  depends_on = [
    null_resource.rsync_kubeconfig_file
  ]

  provisioner "remote-exec" {
    inline = [
      "mv /etc/rancher/k3s/k3s.yaml /etc/rancher/k3s/k3s_external.yaml",
      "sed -i 's#https://127.0.0.1:6443#https://${digitalocean_loadbalancer.loadbalancer.ip}:6443#' /etc/rancher/k3s/k3s_external.yaml",
      "docker run -d --restart=unless-stopped -p 80:80 -p 443:443 --privileged -v /etc/rancher/k3s:/etc/rancher/k3s -e CATTLE_BOOTSTRAP_PASSWORD=${var.rancher_bootstrap_password} rancher/rancher:latest --acme-domain ${var.rancher_domain_name} --kubeconfig /etc/rancher/k3s/k3s_external.yaml"
    ]

    connection {
      type     = "ssh"
      user     = "root"
      host     = digitalocean_loadbalancer.loadbalancer.ip
      private_key = file(var.ssh_private_key_path)
    }
  }
}


