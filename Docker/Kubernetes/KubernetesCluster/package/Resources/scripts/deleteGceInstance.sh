#!/bin/bash
# This script calls compute_api.py to deletes GCE instance from cloud

# To delete a GCE node, it requires the name of instance and it's zone
# This script receives name and zone as arguments and pass them to
# compute_api.py file
# This script is invoked when "deleteGceNode" scheduled

# Args:
# $1 - instance name to delete
# $2 - Zone that instance created
# zone($2) is an optiona argument

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

# change the zone if specified
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
