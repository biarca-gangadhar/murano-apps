#!/bin/bash
echo "deleting Gce Node" >> /tmp/autoscale.log
sudo bash /opt/bin/autoscale/deleteGceNode.sh >> /tmp/autoscale.log

