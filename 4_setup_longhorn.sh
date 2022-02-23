helm repo add longhorn https://charts.longhorn.io &
helm repo update &
exec helm install longhorn longhorn/longhorn --namespace longhorn-system --create-namespace
echo "helm install longhorn OK!"
echo "exec 'kubectl -n longhorn-system get pods -w' to watch the status"
