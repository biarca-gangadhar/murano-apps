#!/bin/bash
# This script adds GCE node to Murano k8s cluster.

set -e

LOG_FILE="/var/log/gce.log"
SCRIPTS_PATH="/opt/bin/autoscale/gce"
conf_file="/etc/autoscale/autoscale.conf"
ZONE="us-central1-f"
ACTION="insert"
NAME=$1

if [ -z $NAME ] ; then
    echo "Error: Instance Name not found"
    exit 1
fi

if [ $2 ] ; then
    ZONE=$2
fi

function LOG()
{
    echo $1 >> $LOG_FILE
}

LOG "Creating instance '$NAME' in zone '$ZONE'"
IP=`python ${SCRIPTS_PATH}/compute_api.py --action=$ACTION --zone=$ZONE $NAME`

LOG "Instance created with external IP '$IP'"
echo $IP
sleep 5
exit 0
