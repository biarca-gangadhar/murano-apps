#!/bin/bash
echo "deleting Gce Node $1 - $2" >> /var/log/gce.log
sudo bash /opt/bin/autoscale/deleteGceNode.sh $1 $2 >> /var/log/gce.log
cat /tmp/deleteGCENode
