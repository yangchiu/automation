# Generate RKE config file (for rke only)
output "rke_config" {
  depends_on = [
    aws_instance.aws_instance_controlplane,
    aws_instance.aws_instance_worker,
    aws_eip.aws_eip_controlplane,
    aws_eip_association.aws_eip_assoc,
    null_resource.wait_for_docker_start_controlplane,
    null_resource.wait_for_docker_start_worker
  ]

  value = var.k8s_distro_name == "rke" ? yamlencode({
    "kubernetes_version": local.k8s_distro_version,
    "nodes": concat(
     [
      for controlplane_instance in aws_instance.aws_instance_controlplane : {
           "address": controlplane_instance.private_ip,
           "hostname_override": controlplane_instance.tags.Name,
           "user": "ubuntu",
           "role": ["controlplane","etcd"]
          }

     ],
     [
      for worker_instance in aws_instance.aws_instance_worker : {
           "address": worker_instance.private_ip,
           "hostname_override": worker_instance.tags.Name,
           "user": "ubuntu",
           "role": ["worker"]
         }
     ]
    ),
    "bastion_host": {
      "address": aws_eip.aws_eip_controlplane[0].public_ip
      "user": "ubuntu"
      "port":  22
      "ssh_key_path": var.aws_ssh_private_key_file_path
    },
    "authentication": {
      "strategy": "x509"
      "sans": [aws_eip.aws_eip_controlplane[0].public_ip]
    }
  }) : null
}

output "rke_config_cluster2" {
  depends_on = [
    aws_instance.aws_instance_cluster2_controlplane,
    aws_instance.aws_instance_cluster2_worker,
    aws_eip.aws_eip_cluster2_controlplane,
    aws_eip_association.aws_eip_assoc_cluster2,
    null_resource.wait_for_docker_start_controlplane_cluster2,
    null_resource.wait_for_docker_start_worker_cluster2
  ]

  value = var.k8s_distro_name == "rke" ? yamlencode({
    "kubernetes_version": local.k8s_distro_version,
    "nodes": concat(
     [
      for controlplane_instance in aws_instance.aws_instance_cluster2_controlplane : {
           "address": controlplane_instance.private_ip,
           "hostname_override": controlplane_instance.tags.Name,
           "user": "ubuntu",
           "role": ["controlplane","etcd"]
          }

     ],
     [
      for worker_instance in aws_instance.aws_instance_cluster2_worker : {
           "address": worker_instance.private_ip,
           "hostname_override": worker_instance.tags.Name,
           "user": "ubuntu",
           "role": ["worker"]
         }
     ]
    ),
    "bastion_host": {
      "address": aws_eip.aws_eip_cluster2_controlplane[0].public_ip
      "user": "ubuntu"
      "port":  22
      "ssh_key_path": var.aws_ssh_private_key_file_path
    },
    "authentication": {
      "strategy": "x509"
      "sans": [aws_eip.aws_eip_cluster2_controlplane[0].public_ip]
    }
  }) : null
}
