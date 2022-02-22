helm repo add longhorn https://charts.longhorn.io
helm repo update
exec helm install longhorn longhorn/longhorn --namespace longhorn-system --create-namespace
exec kubectl -n longhorn-system get pod -w
