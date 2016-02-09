#!/bin/bash
# reconfigure docker network setting

if [ "$(id -u)" != "0" ]; then
  echo >&2 "Please run as root"
  exit 1
fi

source ~/kube/config-default.sh

attempt=0
while [[ ! -f /run/flannel/subnet.env ]]; do
    if (( attempt > 200 )); then
      echo "timeout waiting for /run/flannel/subnet.env" >> ~/kube/err.log
      exit 2
    fi
    attempt=$((attempt+1))
    sleep 3
done

sudo ip link set dev docker0 down
sudo brctl delbr docker0

source /run/flannel/subnet.env

echo DOCKER_OPTS=\"${DOCKER_OPTS} -H tcp://127.0.0.1:4243 -H unix:///var/run/docker.sock \
       --bip=${FLANNEL_SUBNET} --mtu=${FLANNEL_MTU}\" > /etc/default/docker
sudo service docker restart

