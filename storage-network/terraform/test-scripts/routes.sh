# Update nodes eth1 IP to N1, N2, N3
N1="10.0.2.234"
N2="10.0.2.233"
N3="10.0.2.30"

STORAGE_NETWORK_PREFIX="192.168"
ACTION="add"

ETH1_IP=`ip a | grep eth1 | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*'  | awk '{print $2}'`

[[ ${ETH1_IP} != ${N1} ]] && ip r ${ACTION} ${STORAGE_NETWORK_PREFIX}.1.0/24 via ${N1} dev eth1
[[ ${ETH1_IP} != ${N2} ]] && ip r ${ACTION} ${STORAGE_NETWORK_PREFIX}.2.0/24 via ${N2} dev eth1
[[ ${ETH1_IP} != ${N3} ]] && ip r ${ACTION} ${STORAGE_NETWORK_PREFIX}.3.0/24 via ${N3} dev eth1