#!/bin/bash

action=$1
gcp=$2

AUTO_FLAG_FILE="/tmp/autoscale"

if [ "$action" == "up" ] || [ "$action" == "down" ]
then
    if [  -z $gcp ]
    then
       echo "Scaling $action .."
    elif [ $gcp == "gce" ]
    then
       echo "Scaling $action gce.."
    else
       echo "Unknow parameter: $gcp"
       exit 0
    fi
else
  echo "Unknown action: $action"
  exit 0
fi

data_file="/etc/autoscale/autoscale.conf"
env_name=$(awk -F "=" '/^env_name/ {print $2}' $data_file)
OPENSTACK_IP=$(awk -F "=" '/^OPENSTACK_IP/ {print $2}' $data_file)
tenant=$(awk -F "=" '/^tenant/ {print $2}' $data_file)
username=$(awk -F "=" '/^username/ {print $2}' $data_file)
password=$(awk -F "=" '/^password/ {print $2}' $data_file)
header="Content-type: application/json"

# Get Keystone token
token=`curl -s -d '{ "auth": {"tenantName": "'"$tenant"'", "passwordCredentials": {"username": "'"$username"'", "password": "'"$password"'"}}}' -H "$header" http://$OPENSTACK_IP:5000/v2.0/tokens | jq --raw-output '.access.token.id'`
echo "Token: $token"

# Get the k8s environment ID.
envs=$(curl -s -H "X-Auth-Token: $token" http://$OPENSTACK_IP:8082/v1/environments)
total_envs=`echo $envs | jq ".environments |  length"`
count=0
while [ $count -lt $total_envs ]; do
    name=`echo $envs | jq --raw-output ".environments[$count].name"`
    if [ $env_name == $name ] ; then
        env_id=`echo $envs | jq --raw-output ".environments[$count].id"`
        break
    fi
    let count=count+1
done

if [ -z "$env_id" ] ; then
    echo "$env_name not found"
    exit 1
fi

echo "Env ID: $env_id"
services=$(curl -s -H "X-Auth-Token: $token" http://$OPENSTACK_IP:8082/v1/environments/$env_id/services)

# Get action Id's in easy and dirty way
scaleUp=`echo $services | grep -o '[a-z0-9-]*_scaleNodesUp'`
scaleDown=`echo $services | grep -o '[a-z0-9-]*_scaleNodesDown'`
scaleGceUp=`echo $services | grep -o '[a-z0-9-]*_addGceNode'`
scaleGceDown=`echo $services | grep -o '[a-z0-9-]*_deleteGceNode'`

#  up
if [ -z $gcp ] && [ $action == "up" ] ; then
    echo "Action ID: $scaleUp"
    task=$(curl -s -H "X-Auth-Token: $token" -H "Content-Type: application/json" -d "{}" http://$OPENSTACK_IP:8082/v1/environments/$env_id/actions/$scaleUp)
elif [ -z $gcp ] && [ $action == "down" ] ; then
    echo "Action ID: $scaleDown"
    task=$(curl -s -H "X-Auth-Token: $token" -H "Content-Type: application/json" -d "{}" http://$OPENSTACK_IP:8082/v1/environments/$env_id/actions/$scaleDown)
elif [ $gcp == "gce" ] && [ $action == "up" ]; then
    echo 1 > $AUTO_FLAG_FILE
    echo "Action ID: $scaleGceUp"
    task=$(curl -s -H "X-Auth-Token: $token" -H "Content-Type: application/json" -d "{}" http://$OPENSTACK_IP:8082/v1/environments/$env_id/actions/$scaleGceUp)
elif [ $gcp == "gce" ] && [ $action == "down" ]; then
    echo 1 > $AUTO_FLAG_FILE
    echo "Action ID: $scaleGceDown"
    task=$(curl -s -H "X-Auth-Token: $token" -H "Content-Type: application/json" -d "{}" http://$OPENSTACK_IP:8082/v1/environments/$env_id/actions/$scaleGceDown)
fi

task_id=`echo $task | jq --raw-output ".task_id" 2> /dev/null`
if [ $? -ne 0 ] ; then
    echo 0 > $AUTO_FLAG_FILE
    #echo "error: $task"
    echo "Another deployment is going on.."
    exit 1
fi

if [ ! $task_id ]; then
    echo 0  > $AUTO_FLAG_FILE
    echo "Another deployment is going on.."
    exit 1
fi


echo "Task ID: $task_id"

echo "Waiting for task to complete.."

# function that checks task complition. 0 if finish, 1 otherwise
function finish_task {
   result=$(curl -s -H "X-Auth-Token: $token" http://$OPENSTACK_IP:8082/v1/environments/$env_id/actions/$task_id)
   if [ $(echo $result | jq ".isException") == null ] ; then
       echo "1"
   else
       echo "0"
   fi
}

# polling for task complition
while true; do
  stat=$(finish_task)
  if [ $stat == "0" ] ; then
    result=$(curl -s -H "X-Auth-Token: $token" http://$OPENSTACK_IP:8082/v1/environments/$env_id/actions/$task_id)
    if [ $(echo $result | jq ".isException") == "false" ] ; then
       echo 0 > $AUTO_FLAG_FILE
       echo "Done"
       exit 0
    else
       echo 0 > $AUTO_FLAG_FILE
       echo "Exception: $(echo $result | jq ".result")"
       exit 1
    fi
  fi
  sleep 1
done

