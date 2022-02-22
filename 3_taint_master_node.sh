kubectl taint nodes c1-control node-role.kubernetes.io/master=true:NoExecute
kubectl taint nodes c1-control node-role.kubernetes.io/master=true:NoSchedule
