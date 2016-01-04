#!/bin/bash
echo "Adding Gce Node. Received args: $1 - $2 - $3 - $4 - $5" >> /var/log/gce.log
sudo bash /opt/bin/autoscale/addGceNode.sh $1 $2 $3 $4 $5  >> /var/log/gce.log
