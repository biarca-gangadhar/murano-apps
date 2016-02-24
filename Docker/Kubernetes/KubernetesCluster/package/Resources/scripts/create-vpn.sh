#!/bin/bash
# Creates VPN connection between Murano instanecs and GCE instances

# $1 - GCE external IP
# $2 - openVPN Server IP

LOG_FILE="/var/log/gce.log"

if [ -z $1 ] || [ -z $2 ] ; then
    echo "$0: Requires GCE external IP and  OpenVPN Server IP as inputs"
    exit 1
fi


echo "Creating VPN connection. VPN Server IP: $2 and GCE IP: $1" >> $LOG_FILE

GCE_EXTERNAL_IP=$1
OPENVPN_SERVER_IP=$2

# Remove old keys if exists, from known_hosts
ssh-keygen -f "/root/.ssh/known_hosts" -R $GCE_EXTERNAL_IP &>> $LOG_FILE

# Instace just started. Needs time to start ssh service. So try 5 times
count=0
while true; do
  echo "Doing ssh-copy-id" >> $LOG_FILE
  ssh-copy-id root@$GCE_EXTERNAL_IP -o "StrictHostKeyChecking=no" &> /dev/null
  if [ $? != 0 ] && [ $count -lt 5 ]; then
      echo "$count:SSH-copy-id failed. Rechecking" >> $LOG_FILE
      sleep 5
      count=$((count+1))
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

# Request the id_rsa.pub file from OPenVPN Server
ssh_id=$(curl -s http://$OPENVPN_SERVER_IP:5000/api/v1/id_rsa)
echo "id_rsa of '$OPENVPN_SERVER_IP': $ssh_id"  >> $LOG_FILE

# Only this instance have SSH access. Add openVPN id_rsa to auth keys of GCE instance.
# So OpenVPN server will also get SSH access
ssh root@$GCE_EXTERNAL_IP "echo $ssh_id >> /root/.ssh/authorized_keys"
if [ $? != "0" ] ; then
   echo "OpenVPN ssh not ssuccessfull" >> $LOG_FILE
fi
echo "Added OpenVPN Server to authorized keys." >> $LOG_FILE

# Request OpenVPN to create tap interface
result=$(curl -s http://$OPENVPN_SERVER_IP:5000/api/v1/create/$GCE_EXTERNAL_IP)
if [ $result != "OK" ] ; then
    echo "VPN creation error"
    exit 1
fi

echo "VPN Creation done" >> $LOG_FILE

# It takes time to get tap interface in Instance. Try 5 times
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
    count=$((count+1))
done
echo "Tap IP: $tapIP" >> $LOG_FILE
echo $tapIP
exit 0
