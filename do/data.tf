data "template_file" "k3s_server" {
  template = file("${path.module}/user-data-scripts/k3s_server.sh.tpl")
  vars = {
    k3s_cluster_secret = random_password.cluster_secret.result
    k3s_server_public_ip = digitalocean_loadbalancer.loadbalancer.ip
    k3s_version =  var.k8s_distro_version
  }
}

data "template_file" "k3s_agent" {
  template = file("${path.module}/user-data-scripts/k3s_agent.sh.tpl")
  vars = {
    k3s_cluster_secret = random_password.cluster_secret.result
    k3s_server_url = "https://${digitalocean_loadbalancer.loadbalancer.ip}:6443"
    k3s_version =  var.k8s_distro_version
  }
}
