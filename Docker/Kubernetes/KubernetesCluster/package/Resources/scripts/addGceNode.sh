#!/bin/bash
# Add a GCE node to K8S cluster

# Args:
# $1 - AutoScale: Tue/False
# $2 - Master node IP
# $3 - Node IP that is going to add
# $4 - username of the node
# $5 - Password of the node

echo "Adding a Gce Node. Received args: $*" >> /var/log/gce.log
AUTOSCALE=$1
MASTER_IP=$2
NODE_IP=$3
USERNAME=$4
PASSWORD=$5
bash /opt/bin/autoscale/addGceNode.sh $MASTER_IP $NODE_IP $USERNAME $PASSWORD >> /var/log/gce.log
if [ $AUTOSCALE == "True" ] ; then
    /opt/bin/kubectl label nodes $NODE_IP creationType=Auto >> /var/log/gce.log || true
fi
