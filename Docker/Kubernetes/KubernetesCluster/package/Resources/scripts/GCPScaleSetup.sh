#!/bin/bash

log_file=/var/log/gce.log
cred_file="/etc/autoscale/Credentials.json"
echo "GCE Auto Scale setup starting" >> $log_file
export DEBIAN_FRONTEND=noninteractive
apt-get install python-pip -y
pip install --upgrade google-api-python-client


mkdir -p /etc/autoscale
mkdir -p /opt/bin/autoscale
mkdir -p /opt/bin/autoscale/gce

cp auto_scale/gce/compute_api.py /opt/bin/autoscale/gce/compute_api.py

exit 0
