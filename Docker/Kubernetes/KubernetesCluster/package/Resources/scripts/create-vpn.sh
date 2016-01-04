#!/bin/bash

# $1 - GCE external IP
# $2 - openVPN Server IP

LOG_FILE="/var/log/gce.log"

if [ -z $1 ] || [ -z $2 ] ; then
    echo "$0: GCE external IP error"
    exit 1
fi

echo "Got VPNIP: $2 and GCE IP: $1" >> $LOG_FILE

GCE_EXTERNAL_IP=$1
OPENVPN_SERVER_IP=$2

ssh-keygen -f "/root/.ssh/known_hosts" -R $GCE_EXTERNAL_IP &> $LOG_FILE
count=0
while true; do
  echo "Doing ssh-copy-id" >> $LOG_FILE
  ssh-copy-id root@$GCE_EXTERNAL_IP -o "StrictHostKeyChecking=no" &> /dev/null
  if [ $? != 0 ] && [ $count -lt 5 ]; then
      echo "$count:SSH-copy-id failed. Rechecking" >> $LOG_FILE
      sleep 5
      count=$[$count+1]
      continue
  elif [ $count -eq 5 ]; then
      echo "SSH-copy-id timed out.." >> $LOG_FILE
      echo "SSH timeout error"
      exit 1
  else
      echo "SSH-copy-id success" >> $LOG_FILE
      break
  fi
done

ssh_id=`curl -s http://$OPENVPN_SERVER_IP:5000/api/v1/id_rsa`
echo "id_rsa of '$OPENVPN_SERVER_IP': $ssh_id"  >> $LOG_FILE

ssh root@$GCE_EXTERNAL_IP "echo $ssh_id >> /root/.ssh/authorized_keys"
if [ $? != "0" ] ; then
   echo "Ssh not ssuccessfull" >> $LOG_FILE
fi
echo "SSH done" >> $LOG_FILE

result=`curl -s http://$OPENVPN_SERVER_IP:5000/api/v1/create/$GCE_EXTERNAL_IP`
if [ $result != "OK" ] ; then
    echo "VPN creation error"
    exit 1
fi

echo "VPN Creation done" >> $LOG_FILE

count=0
while true; do
    echo "Waiting for TAP IP" >> $LOG_FILE
    sleep 4
    tapIP=$(ssh root@$GCE_EXTERNAL_IP "ifconfig tap0" | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}') 
    if [ $tapIP ] ; then
         break
    elif [ $count -eq 4 ] ; then
         echo "Tap Timeout" >> $LOG_FILE
         echo "Tap timeout"
         exit 1
    fi
    count=$[$count+1]
done
echo "Tap IP: $tapIP" >> $LOG_FILE
echo $tapIP
exit 0
