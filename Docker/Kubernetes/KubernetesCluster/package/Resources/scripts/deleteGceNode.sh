#!/bin/bash

echo "deleting Gce Node $1 - $2" >> /var/log/gce.log
sudo bash /opt/bin/autoscale/deleteGceNode.sh $1 $2 >> /var/log/gce.log

# The above operation writes instance name into /tmp/deleteGCENode, 
# which helps to delete it from Google cloud
cat /tmp/deleteGCENode
