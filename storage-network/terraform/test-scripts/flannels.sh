# Update nodes eth1 IP to N1, N2, N3
N1="10.0.2.234"
N2="10.0.2.233"
N3="10.0.2.30"
NODES=(${N1} ${N2} ${N3})

STORAGE_NETWORK_PREFIX="192.168"

ETH1_IP=`ip a | grep eth1 | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*'  | awk '{print $2}'`

count=1
for n in "${NODES[@]}"; do
    [[ ${ETH1_IP} != $n ]] && ((count=count+1)) && continue

    NET=$count
    break
done

cat << EOF > /run/flannel/multus-subnet-${STORAGE_NETWORK_PREFIX}.0.0.env
FLANNEL_NETWORK=${STORAGE_NETWORK_PREFIX}.0.0/16
FLANNEL_SUBNET=${STORAGE_NETWORK_PREFIX}.${NET}.0/24
FLANNEL_MTU=1472
FLANNEL_IPMASQ=true
EOF