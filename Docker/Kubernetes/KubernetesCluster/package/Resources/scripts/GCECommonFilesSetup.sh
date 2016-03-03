#!/bin/bash
# This script transfers the files  which helps in
# adding/deleting a node to cluster

log_file=/var/log/gce.log
echo "Setting up GCE Common files started" >> $log_file

apt-get update &>> $log_file
apt-get install jq -y &>> $log_file
apt-get install sshpass -y &>> $log_file

# needs proper directory structure to place files
mkdir -p /opt/bin/autoscale
mkdir -p /opt/bin/autoscale/kube
mkdir -p /opt/bin/autoscale/kube/initd
mkdir -p /opt/bin/autoscale/kube/init_conf
mkdir -p /etc/autoscale

# Transfer the files which adds/deletes node into cluster
cp auto_scale/addGceNode.sh /opt/bin/autoscale/addGceNode.sh
cp auto_scale/deleteGceNode.sh /opt/bin/autoscale/deleteGceNode.sh
cp auto_scale/kube/reconfDocker.sh /opt/bin/autoscale/kube/reconfDocker.sh

cp init_conf/etcd.conf /opt/bin/autoscale/kube/init_conf
cp init_conf/kubelet.conf /opt/bin/autoscale/kube/init_conf
cp init_conf/kube-proxy.conf /opt/bin/autoscale/kube/init_conf
cp init_conf/flanneld.conf /opt/bin/autoscale/kube/init_conf

cp initd_scripts/etcd /opt/bin/autoscale/kube/initd
cp initd_scripts/kubelet /opt/bin/autoscale/kube/initd
cp initd_scripts/kube-proxy /opt/bin/autoscale/kube/initd
cp initd_scripts/flanneld /opt/bin/autoscale/kube/initd

if [ ! -f  ~/.ssh/id_rsa ] ; then
    ssh-keygen -f ~/.ssh/id_rsa -t rsa -N ''
fi

echo "Setting up GCE Common files Completed" >> $log_file
exit 0
