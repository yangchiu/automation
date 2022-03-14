#!/bin/bash 

DOCKER_VERSION=20.10

sudo apt-get update 
sudo apt-get install -y build-essential git nfs-common

until (curl https://releases.rancher.com/install-docker/${DOCKER_VERSION}.sh | sudo sh); do
  echo 'docker did not install correctly'                                          
  sleep 2   
done

sudo usermod -aG docker ubuntu

docker run -d --restart=unless-stopped -p 80:80 -p 443:443 --privileged rancher/rancher:2.5.12
