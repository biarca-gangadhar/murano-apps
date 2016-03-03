#!/bin/bash
# This script creates a  GCE instance.

# Arguments:
# $1 - Instance Name
# $2 - Zone that instance has to create
# zone($2) is optional argument, by default it's "us-central1-f"

set -e

LOG_FILE="/var/log/gce.log"
SCRIPTS_PATH="/opt/bin/autoscale/gce"
# Default zone is "us-central1-f"
ZONE="us-central1-f"
ACTION="insert"
NAME=$1

if [ -z $NAME ] ; then
    echo "Error: Instance Name not found"
    exit 1
fi

# Change the zone to received zone
if [ $2 ] ; then
    ZONE=$2
fi

function LOG()
{
    echo $1 >> $LOG_FILE
}

LOG "Creating instance '$NAME' in zone '$ZONE'"
# Once instance created successfully, it returns it's external IP
IP=$(python ${SCRIPTS_PATH}/compute_api.py --action=$ACTION --zone=$ZONE $NAME)

LOG "Instance created with external IP '$IP'"
echo $IP
sleep 5
exit 0
