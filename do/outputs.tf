output "controlplane_ip" {
  value = digitalocean_droplet.controlplane[*].ipv4_address
}

output "worker_ip" {
  value = digitalocean_droplet.worker[*].ipv4_address
}

output "loadbalancer_ip" {
  value = digitalocean_loadbalancer.loadbalancer.ip
}