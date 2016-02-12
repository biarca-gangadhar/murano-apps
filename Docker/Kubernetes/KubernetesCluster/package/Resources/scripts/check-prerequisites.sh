#!/bin/bash
# This file checks and install docker and bridge-utils packages

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

# Function that check node is in n/w and ssh port is open
function check-ssh-port()
{
  count=0
  while [ $count -le 4 ]; do
     sleep 5
     nc -zw3 $IP 22   # check port 22
     if [ $? -eq 0 ]; then
        LOG "I" "Connection success"
        return 0
     else
        ((count=count+1))
        LOG "I" "Connection failed($count). Retrying.."
     fi
  done
  # SSH port is not in open. 
  return 1
}

check-ssh-port
if [ $? -ne 0 ] ; then
    msg=`build-status "error" "SSH port not opened. Timed out."`
    MESSAGE "E" "$msg"
    exit 0
fi

# setup SSH without asking password every time
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

setup-ssh

# install packages Docker and  bridge-utils
function install-prerequisites()
{
  ssh $NODE "sudo apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D"
  ssh $NODE "echo 'deb https://apt.dockerproject.org/repo ubuntu-trusty main' > /etc/apt/sources.list.d/docker.list"
  ssh $NODE "sudo apt-get update"
  ssh $NODE "DEBIAN_FRONTEND=noninteractive sudo apt-get install docker-engine -y" 
  ssh $NODE "service docker start"

  ssh $NODE "sudo apt-get install bridge-utils -y"
}

# Check docker and bridge-utils are installed
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


# Check pre-requisites, install if not
output=`check-prerequisites`
if [ $? -ne 0 ] ; then
  install-prerequisites
fi

MESSAGE "I" '{"status": "success", "description": "none"}'
LOG "** $0 FINISHED **"
