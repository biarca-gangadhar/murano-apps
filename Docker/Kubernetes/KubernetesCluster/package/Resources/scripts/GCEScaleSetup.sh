#!/bin/bash
# This script copies the compute_api.py file to master node
# compute_api.py creates/deletes the instances
# This file also installs google-api-python-client library for GCE api calls

log_file=/var/log/gce.log
echo "GCE Auto Scale setup started" >> $log_file

apt-get install python-pip -y &>> $log_file
pip install --upgrade google-api-python-client &>> $log_file

mkdir -p /etc/autoscale
mkdir -p /opt/bin/autoscale
mkdir -p /opt/bin/autoscale/gce

# compute_api.py file create/delete GCE instance in cloud
cp auto_scale/gce/compute_api.py /opt/bin/autoscale/gce/compute_api.py

echo "GCE Auto Scale setup completed" >> $log_file
exit 0
