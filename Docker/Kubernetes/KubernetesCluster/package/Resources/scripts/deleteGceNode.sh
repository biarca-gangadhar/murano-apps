#!/bin/bash
echo "deleting Gce Node $1 - $2" >> /tmp/autoscale.log
sudo bash /opt/bin/autoscale/deleteGceNode.sh $1 $2 >> /tmp/autoscale.log
cat /tmp/deleteGCENode
