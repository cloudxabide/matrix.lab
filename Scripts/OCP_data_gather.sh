#!/bin/bash

# wget https://raw.githubusercontent.com/cloudxabide/matrix.lab/main/Scripts/OCP_data_gather.sh
# chmod 0754 OCP_data_gather.sh

# First, see if we are logged in to a cluster
oc get nodes > /dev/null  2>&1  || { echo "ERROR:  you are not logged in to a cluster"; exit 9; }

# If I *can* find a way to figure out the domain dynamically for this, I should.. but, for now:
[ -e $BASE_DOMAIN ] && BASE_DOMAIN="clouditoutloud.com"

aws_infra_info() {
[ ! -f aws_cli_inventory.sh ] && wget https://raw.githubusercontent.com/cloudxabide/devops/main/Scripts/aws_cli_inventory.sh
sh ./aws_cli_inventory.sh
}

ocp_info() {
echo "# OCP Status"
echo "# serviceNetwork is implied in the output"
oc status

echo "# OCP Versions (client/server)"
oc version

echo "# ClusterID"
oc get clusterversion -o jsonpath='{.items[].spec.clusterID}{"\n"}'

echo "# Host Subnets"
oc get hostsubnets

echo "# Networking | clusterNetwork"
oc  get network.config/cluster -o jsonpath='{.spec.clusterNetwork},{"\n"}'

echo "# Networking | serviceNetwork"
 oc  get network.config/cluster -o jsonpath='{.spec.serviceNetwork},{"\n"}'
}

aws_infra_info
ocp_info
