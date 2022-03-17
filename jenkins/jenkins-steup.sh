#!/usr/bin/env bash

kubectl create namespace jenkins

helm repo add jenkinsci https://charts.jenkins.io
helm repo update

kubectl apply -f jenkins-volume.yaml
kubectl apply -f jenkins-sa.yaml

chart=jenkinsci/jenkins
helm install jenkins -n jenkins -f jenkins-values.yaml -f jenkins-values-override.yaml $chart

#helm uninstall jenkins -n jenkins

kubectl exec --namespace jenkins -it svc/jenkins -c jenkins -- /bin/cat /run/secrets/chart-admin-password && echo