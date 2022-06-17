# https://aws.amazon.com/premiumsupport/knowledge-center/ec2-ubuntu-secondary-network-interface/

1.    Create a configuration file for the secondary interface:

vi /etc/netplan/51-eth1.yaml

2.    Add the following lines to the 51-eth1.yaml file. Make sure you edit the following example to match your use case:

network:
  version: 2
  renderer: networkd
  ethernets:
    eth1:
      addresses:
       - 10.0.2.234/20
      dhcp4: no
      routes:
       - to: 0.0.0.0/0
         via: 10.0.2.1 # Default gateway
         table: 1000

4.    Apply the network configuration:

netplan --debug apply

