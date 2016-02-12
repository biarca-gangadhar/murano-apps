#!/bin/bash
# Add a GCE node to K8S cluster

# Args: 
# $1 - NOdeIp that is going add in cluster
# $2 - Type of Node like 'existing' or 'new'
# $3 - K8S Master node Ip for Kubelet configuration
# $4 - Username if $2=existing , Instance Name if $2=new
# $5 - Password if $2=existing

echo "Adding Gce Node. Received args: $1 - $2 - $3 - $4 - $5" >> /var/log/gce.log
sudo bash /opt/bin/autoscale/addGceNode.sh $1 $2 $3 $4 $5  >> /var/log/gce.log
