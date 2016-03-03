#!/bin/bash
# This script deletes the GCE node from cluster

# Args:
# $1: Node IP to delete
# $2: Username of the node

echo "deleting Gce Node $1 - $2" >> /var/log/gce.log
bash /opt/bin/autoscale/deleteGceNode.sh $1 $2 >> /var/log/gce.log
