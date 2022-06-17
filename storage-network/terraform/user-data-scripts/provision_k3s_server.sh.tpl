#!/bin/bash 

set -e

apt-get update
apt-get install -y nfs-common jq

until (curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --tls-san ${k3s_server_public_ip}" INSTALL_K3S_VERSION="${k3s_version}" K3S_CLUSTER_SECRET="${k3s_cluster_secret}" K3S_KUBECONFIG_MODE="644" sh -); do
  echo 'k3s server did not install correctly'
  sleep 2
done

until (kubectl get pods -A | grep 'Running'); do
  echo 'Waiting for k3s startup'
  sleep 5
done

until (curl https://releases.rancher.com/install-docker/20.10.sh | sudo sh); do
  echo 'docker did not install correctly'
  sleep 2
done

usermod -aG docker ubuntu
useradd jenkins
usermod -aG docker jenkins
chmod 777 /var/run/docker.sock