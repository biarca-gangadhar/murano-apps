#!/bin/bash

DESCRIPTION="None"
LOG_FILE="/var/log/gce.log"
exec 2>>${LOG_FILE}

# prints to LOG_FILE
function LOG()
{
   if [ $# -eq 1 ] ; then
     LEVEL="I"
     MSG=$1
   else
     LEVEL=$1
     MSG=$2
   fi
   NOW=$(date -u +"%d-%m-%Y %H:%M:%S")
   echo "$NOW UTC - $LEVEL $MSG" >> $LOG_FILE
}

# prints to stdout and LOG_FILE
function MESSAGE()
{
   echo "$2"
   LOG "$1" "$2"
}

function build-status()
{
  echo '{"status": "'"$1"'", "description": "'"$2"'"}'
}

LOG "** $0 STARTED **"

if [ $# -eq 3 ] ; then
  IP=$1
  USERNAME=$2
  PASSWORD=$3
elif [ $# -eq 2 ] ; then
  IP=$1
  USERNAME=$2
  PASSWORD=""
else
  msg=`build-status "error" "Worng arguments"`
  MESSAGE "E" "$msg"
  exit 0
fi

NODE="$USERNAME@$IP"
LOG "IP: $IP, USERNAME: $USERNAME, PASSWORD: $PASSWORD, NODE: $NODE"

function check-ssh-port()
{
  count=0
  while [ $count -le 4 ]; do
     sleep 1
     nc -zw3 $IP 22
     if [ $? -eq 0 ]; then
        LOG "I" "Connection success"
        return 0
     else
        ((count=count+1))
        LOG "I" "Connection failed($count). Retrying.."
     fi
  done
  return 1
}

function setup-ssh()
{
  ssh-keygen -R $IP &> /dev/null
  ssh-keyscan -H $IP >> ~/.ssh/known_hosts
  if [ -z $PASSWORD ] ; then
    ssh-copy-id -o StrictHostKeyChecking=no $NODE
  else
    sshpass -p $PASSWORD ssh-copy-id -o StrictHostKeyChecking=no $NODE
  fi
}

function install-prerequisites()
{
  ssh $NODE "sudo apt-get install docker-engine -y" 
  ssh $NODE "service docker start"
  ssh $NODE "sudo apt-get install bridge-utils -y"
}

function check-prerequisites()
{
  ssh $NODE "sudo docker ps" &> /dev/null
  if [ $? -ne 0 ]; then
    return 1
  fi
  ssh $NODE "brctl --version" &> /dev/null
  if [ $? -ne 0 ]; then
    return 1
  fi
  return 0
}


check-ssh-port
if [ $? -ne 0 ] ; then
    msg=`build-status "error" "SSH port not opened. Timed out."`
    MESSAGE "E" "$msg"
    exit 0
fi

setup-ssh

output=`check-prerequisites`
if [ $? -ne 0 ] ; then
  install-prerequisites
fi

MESSAGE "I" '{"status": "success", "description": "none"}'
LOG "** $0 FINISHED **"
