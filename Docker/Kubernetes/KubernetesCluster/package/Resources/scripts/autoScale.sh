#!/bin/bash

#
# command line arguments
#

# $1  - max_vms_limit 
# $2  - min_vms_limit
# $3  - MAX_CPU_LIMIT
# $4  - MIN_CPU_LIMIT
# $5  - MASTER
# $6  - env_name
# $7  - OPENSTACK_IP
# $8  - tenant
# $9  - username
# $10 - password
# $11 - Enabe Hybrid Cloud 
# $12 - GCP Minion Node
# $13 - GCP Node Detaileos
# $14 - GCP Username
# $15 - GCP Password

log_file=/var/log/autoscale.log
echo "Auto Scale setup starting" >> $log_file
conf_file=auto_scale/autoscale.conf

mkdir -p /etc/autoscale
mkdir -p /opt/bin/autoscale

sed -i "/^\[DEFAULT]/ a\max_vms_limit=${1}" $conf_file
sed -i "/^\[DEFAULT]/ a\min_vms_limit=${2}" $conf_file
sed -i "/^\[DEFAULT]/ a\MAX_CPU_LIMIT=${3}" $conf_file
sed -i "/^\[DEFAULT]/ a\MIN_CPU_LIMIT=${4}" $conf_file
sed -i "/^\[DEFAULT]/ a\MASTER=${5}" $conf_file
sed -i "/^\[DEFAULT]/ a\env_name=${6}" $conf_file
sed -i "/^\[DEFAULT]/ a\password=${10}" $conf_file
sed -i "/^\[DEFAULT]/ a\tenant=${8}" $conf_file
sed -i "/^\[DEFAULT]/ a\username=${9}" $conf_file
sed -i "/^\[DEFAULT]/ a\OPENSTACK_IP=${7}" $conf_file
   if [[ ${11} == "True" ]];
   then
      sed -i "/^\[GCE]/ a\gcp_ip=${13}" $conf_file
      sed -i "/^\[GCE]/ a\gcp_minion_nodes=${12}" $conf_file
      sed -i "/^\[GCE]/ a\gcp_password=${15}" $conf_file
      sed -i "/^\[GCE]/ a\gcp_username=${14}" $conf_file
      mkdir -p /opt/bin/autoscale/kube
      mkdir -p /opt/bin/autoscale/kube/initd
      cp auto_scale/addGceNode.sh /opt/bin/autoscale/
      cp auto_scale/deleteGceNode.sh /opt/bin/autoscale/
      cp auto_scale/gceIpManager.sh /opt/bin/autoscale/
      cp auto_scale/kube/reconfDocker.sh /opt/bin/autoscale/kube
      cp auto_scale/kube/initd/etcd /opt/bin/autoscale/kube/initd
      cp auto_scale/kube/initd/flanneld /opt/bin/autoscale/kube/initd
      cp auto_scale/kube/initd/kubelet /opt/bin/autoscale/kube/initd
      cp auto_scale/kube/initd/kube-proxy /opt/bin/autoscale/kube/initd
   fi
cp auto_scale/autoscale.conf /etc/autoscale/
chmod +x auto_scale/*
cp auto_scale/metrics.py /opt/bin/autoscale/
cp auto_scale/scale.sh /opt/bin/autoscale/
cp auto_scale/autoscale /etc/init.d/
sudo apt-get install python3-numpy -y
sudo apt-get install jq
sudo apt-get install sshpass -y
service autoscale start

exit 0

