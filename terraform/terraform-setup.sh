#!/usr/bin/env bash

set -x

DISTRO=ubuntu
export TF_VAR_arch=amd64
export TF_VAR_k8s_distro_name=rke2

if [[ ${TF_VAR_arch} == "amd64" ]]; then
	terraform -chdir=aws/${DISTRO} init
	terraform -chdir=aws/${DISTRO} apply -auto-approve -no-color
	
	if [[ ${TF_VAR_k8s_distro_name} == "rke" ]]; then
	  # cluster 1
	  rm rke.rkestate
	  rm kube_config_rke.yml
		terraform -chdir=aws/${DISTRO} output -raw rke_config > rke.yml
		sleep 30
		rke up --config rke.yml
		mv kube_config_rke.yml rke_cluster.yaml
		SERVER=https://`yq '.authentication.sans[0]' rke.yml`:6443
		yq -i '.clusters[0].cluster.server = "'${SERVER}'"' rke_cluster.yaml
		# cluster 2
	  rm rke.rkestate
	  rm kube_config_rke.yml
		terraform -chdir=aws/${DISTRO} output -raw rke_config_cluster2 > rke.yml
		sleep 30
		rke up --config rke.yml
		mv kube_config_rke.yml rke_cluster2.yaml
		SERVER=https://`yq '.authentication.sans[0]' rke.yml`:6443
		yq -i '.clusters[0].cluster.server = "'${SERVER}'"' rke_cluster2.yaml
	fi
else
	terraform -chdir=aws/${DISTRO} init
	terraform -chdir=aws/${DISTRO} apply -auto-approve -no-color
fi

if [[ ${TF_VAR_k8s_distro_name} == "rke" ]]; then
  export KUBECONFIG=${PWD}/rke_cluster.yaml
  kubectl config set-context local
  kubectl config use-context local
  kubectl get node -o wide
elif [[ ${TF_VAR_k8s_distro_name} == "rke2" ]]; then
  export KUBECONFIG=${PWD}/aws/${DISTRO}/rke2.yaml
  kubectl config set-context default
  kubectl config use-context default
  kubectl get node -o wide
else
  export KUBECONFIG=${PWD}/aws/${DISTRO}/k3s.yaml
  kubectl config set-context default
  kubectl config use-context default
  kubectl get node -o wide
fi

exit $?
