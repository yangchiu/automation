cat << EOF > nad-192-168-0-0.yaml
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: demo-192-168-0-0
  namespace: kube-system
  #namespace: longhorn-system
spec:
  config: '{
      "cniVersion": "0.3.1",
      "type": "flannel",
      "subnetFile": "/run/flannel/multus-subnet-192.168.0.0.env",
      "dataDir": "/var/lib/cni/multus-subnet-192.168.0.0",
      "delegate": {
        "type": "ipvlan",
        "master": "eth1",
        "mode": "l3",
          "capabilities": {
            "ips": true
        }
      },
      "kubernetes": {
          "kubeconfig": "/etc/cni/net.d/multus.d/multus.kubeconfig"
      }
    }'
EOF