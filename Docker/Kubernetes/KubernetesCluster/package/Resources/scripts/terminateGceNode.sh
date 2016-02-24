#!/bin/bash
# This script deletes GCE instance from cloud

set -e

LOG_FILE="/var/log/gce.log"
SCRIPTS_PATH="/opt/bin/autoscale/gce"
ZONE="us-central1-f"  # default zone
ACTION="delete"
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

LOG "Deleting instance '$NAME' in zone '$ZONE'"
python ${SCRIPTS_PATH}/compute_api.py --action=$ACTION --zone=$ZONE $NAME

exit 0
