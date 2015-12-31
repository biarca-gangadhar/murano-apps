#!/bin/bash
echo "Adding Gce Node $1 - $2 - $3 - $4 - $5" >> /tmp/autoscale.log
sudo bash /opt/bin/autoscale/addGceNode.sh $1 $2 $3 $4 $5
