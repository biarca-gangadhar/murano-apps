#!/bin/bash

log_file=/var/log/gce.log
echo "GCE Auto Scale setup starting" >> $log_file

sudo apt-get install jq -y &> /dev/null
sudo apt-get install sshpass -y &> /dev/null
mkdir -p /opt/bin/autoscale
mkdir -p /opt/bin/autoscale/kube
mkdir -p /opt/bin/autoscale/kube/initd
mkdir -p /etc/autoscale

cp auto_scale/addGceNode.sh /opt/bin/autoscale/addGceNode.sh
cp auto_scale/deleteGceNode.sh /opt/bin/autoscale/deleteGceNode.sh
cp auto_scale/gceIpManager.sh /opt/bin/autoscale/gceIpManager.sh
cp auto_scale/kube/reconfDocker.sh /opt/bin/autoscale/kube/reconfDocker.sh
cp auto_scale/kube/initd/etcd /opt/bin/autoscale/kube/initd/etcd
cp auto_scale/kube/initd/flanneld /opt/bin/autoscale/kube/initd/flanneld
cp auto_scale/kube/initd/kubelet /opt/bin/autoscale/kube/initd/kubelet
cp auto_scale/kube/initd/kube-proxy /opt/bin/autoscale/kube/initd/kube-proxy

if [ ! -f  ~/.ssh/id_rsa ] ; then
    ssh-keygen -f ~/.ssh/id_rsa -t rsa -N ''
fi

exit 0

