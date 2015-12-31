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
# $11 - total no of nodes

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
sed -i "/^\[GCE]/ a\gcp_minion_nodes=${11}" $conf_file
cp auto_scale/autoscale.conf /etc/autoscale/
chmod +x auto_scale/*
export DEBIAN_FRONTEND=noninteractive
cp auto_scale/metrics.py /opt/bin/autoscale/
cp auto_scale/scale.sh /opt/bin/autoscale/
cp auto_scale/autoscale /etc/init.d/
sudo apt-get install python3-numpy -y
sudo apt-get install jq -y
sudo apt-get install sshpass -y
service autoscale start
if [ ! -f  ~/.ssh/id_rsa ] ; then
            ssh-keygen -f ~/.ssh/id_rsa -t rsa -N ''
fi
exit 0

