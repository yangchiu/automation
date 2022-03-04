#!/usr/bin/env bash

set -x

DISTRO=ubuntu
export TF_VAR_arch=amd64
export TF_VAR_k8s_distro_name=k3s

if [[ ${TF_VAR_arch} == "amd64" ]]; then
	terraform -chdir=aws/${DISTRO} init
	terraform -chdir=aws/${DISTRO} apply -auto-approve -no-color
	
	if [[ ${TF_VAR_k8s_distro_name} =~ [rR][kK][eE] ]]; then
    terraform -chdir=aws/${DISTRO} apply -auto-approve -no-color -refresh-only
		terraform -chdir=aws/${DISTRO} output -raw rke_config > rke.yml
		sleep 30
		rke up --config rke.yml
	fi
else
	terraform -chdir=aws/${DISTRO} init
	terraform -chdir=aws/${DISTRO} apply -auto-approve -no-color
fi

export KUBECONFIG=${PWD}/aws/${DISTRO}/k3s.yaml
kubectl config set-context default
kubectl config use-context default
kubectl get node -o wide

exit $?
