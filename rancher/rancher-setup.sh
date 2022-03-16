helm repo add rancher-latest https://releases.rancher.com/server-charts/latest

kubectl create namespace cattle-system

kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.0.4/cert-manager.crds.yaml
kubectl create namespace cert-manager

helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager --namespace cert-manager --version v1.4.0
kubectl get pods --namespace cert-manager

# cannot install HA rancher without dns name......
helm install rancher rancher-latest/rancher --namespace cattle-system --set version=2.5.12
# helm install rancher rancher-latest/rancher --namespace cattle-system --set hostname=localhost --version 2.6.3-patch1

kubectl -n cattle-system rollout status deploy/rancher
kubectl -n cattle-system get deploy rancher
