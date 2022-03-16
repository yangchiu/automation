#!/usr/bin/env bash

set -x

DISTRO=ubuntu
export TF_VAR_arch=arm64
export TF_VAR_k8s_distro_name=k3s

if [[ ${TF_VAR_arch} == "amd64" ]]; then
	terraform -chdir=aws/${DISTRO} init
	terraform -chdir=aws/${DISTRO} apply -auto-approve -no-color
	
	if [[ ${TF_VAR_k8s_distro_name} =~ [rR][kK][eE] ]]; then
	  # cluster 1
	  rm rke.rkestate
	  rm kube_config_rke.yml
		terraform -chdir=aws/${DISTRO} output -raw rke_config > rke.yml
		sleep 30
		rke up --config rke.yml
		mv kube_config_rke.yml rke_cluster.yaml
		# cluster 2
	  rm rke.rkestate
	  rm kube_config_rke.yml
		terraform -chdir=aws/${DISTRO} output -raw rke_config_cluster2 > rke.yml
		sleep 30
		rke up --config rke.yml
		mv kube_config_rke.yml rke_cluster2.yaml
	fi
else
	terraform -chdir=aws/${DISTRO} init
	terraform -chdir=aws/${DISTRO} apply -auto-approve -no-color
fi

if [[ ${TF_VAR_k8s_distro_name} =~ [rR][kK][eE] ]]; then
  export KUBECONFIG=${PWD}/rke_cluster.yaml
else
  export KUBECONFIG=${PWD}/aws/${DISTRO}/k3s.yaml
fi
kubectl config set-context default
kubectl config use-context default
kubectl get node -o wide

exit $?
