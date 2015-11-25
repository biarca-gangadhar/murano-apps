#!/bin/bash
# This script adds GCE node to Murano k8s cluster.

set -e


GCP_FILE="/opt/bin/autoscale/gceIpManager.sh"
conf_file="/etc/autoscale/autoscale.conf"

NODE_IP=$(bash $GCP_FILE free_node)
NODE_USER=$(awk -F "=" '/^gcp_username/ {print $2}' $conf_file)
NODE_PASSWD=$(awk -F "=" '/^gcp_password/ {print $2}' $conf_file)

if [ -z $NODE_USER ] || [ -z $NODE_PASSWD ] ; then
    echo '{ "error": "GCE nodes not configured"}'
    exit 1
fi

if [ $NODE_IP == "0" ] ; then
    echo '{ "error": "No GCE nodes available"}'
    exit 0
fi

NODE="$NODE_USER@$NODE_IP"
echo $NODE
MASTER_IP=$(awk -F "=" '/^MASTER/ {print $2}' $conf_file)
MASTER_URL="http://$MASTER_IP:8080"

# don't afraid to change the ports
PORT_ETCD_ADVERT_PEER=7001
PORT_ETCD_ADVERT_CLIENT=4001
PORT_ETCD_LISTEN_PEER=7001
PORT_ETCD_LISTEN_CLIENT=4001
PORT_KUBELET=10250
PORT_K8S_MASTER=8080

BIN_ETCDCTL=/opt/bin/etcdctl
BIN_KUBECTL=/opt/bin/kubectl



function ssh-setup()
{

   if [ ! -f  ~/.ssh/id_rsa ] ; then
       ssh-keygen -f ~/.ssh/id_rsa -t rsa -N ''
   fi
   ssh-keyscan $NODE_IP >> ~/.ssh/known_hosts
   sshpass -p $NODE_PASSWD ssh-copy-id $NODE
}

# generate a etcd member name for new node.
function create-etcd-name() {
    # this func creates etcd names like new0, new1, new2...
    # change name pattern if required. ex: pattern="infra-"
    pattern="gce-"
    count=0
    $BIN_ETCDCTL member list > /tmp/etcd.list
    name="$pattern$count"
    while true
    do
       if grep "$name" /tmp/etcd.list > /dev/null
       then
          ((count=count+1))
          name="$pattern$count"
          continue
       else
          ETCD_NAME=$name
          break
       fi
    done
}

function create-etcd-opts() {
  localhost="127.0.0.1"
  ini_adv_peer="http://$NODE_IP:$PORT_ETCD_ADVERT_PEER,http://$localhost:$PORT_ETCD_ADVERT_PEER"
  listen_peer_urls="http://$NODE_IP:$PORT_ETCD_LISTEN_PEER,http://$localhost:$PORT_ETCD_LISTEN_PEER"
  listen_client_urls="http://$NODE_IP:$PORT_ETCD_LISTEN_CLIENT,http://$localhost:$PORT_ETCD_LISTEN_CLIENT"
  adv_client_urls="http://$NODE_IP:$PORT_ETCD_ADVERT_CLIENT,http://$localhost:$PORT_ETCD_ADVERT_CLIENT"

  OPTS="--name $ETCD_NAME \
  --data-dir /var/lib/etcd \
  --snapshot-count 1000 \
  --initial-advertise-peer-urls  $ini_adv_peer \
  --listen-peer-urls $listen_peer_urls \
  --listen-client-urls $listen_client_urls \
  --advertise-client-urls $adv_client_urls \
  --initial-cluster $ETCD_INITIAL_CLUSTER \
  --initial-cluster-state $ETCD_INITIAL_CLUSTER_STATE"

  ETCD_OPTS=`echo $OPTS | tr -s " "`  # remove extra spaces
}

function create-kube-proxy-opts() {
    OPTS="--logtostderr=false \
          --master=$MASTER_URL \
          --log_dir=$LOG_DIR"
    KUBE_PROXY_OPTS=`echo $OPTS | tr -s " "`  # remove extra spaces
}

function create-kubelet-opts()
{
    OPTS="--address=0.0.0.0 \
          --port=$PORT_KUBELET \
          --hostname_override=$NODE_IP \
          --api_servers=$MASTER_IP:$PORT_K8S_MASTER \
          --log_dir=/var/log/kubernetes \
          --logtostderr=false"
    KUBELET_OPTS=`echo $OPTS | tr -s " "`  # remove extra spaces
}

function create-flanneld-opts()
{
    OPTS="--iface=$NODE_IP"
    FLANNEL_OPTS=`echo $OPTS | tr -s " "`  # remove extra spaces

    # Store the flannel network for reconfiguring
    flannel_net=`/opt/bin/etcdctl get /coreos.com/network/config | jq --raw-output .Network`
    echo FLANNEL_NET=\"$flannel_net\" > /opt/bin/autoscale/kube/config-default.sh
}

function transfer-files() {
    echo "transferring files to $NODE"
    mkdir  -p /opt/bin/autoscale/kube/bin
    cp /opt/bin/etcd /opt/bin/kubelet /opt/bin/kube-proxy \
                /opt/bin/flanneld /opt/bin/etcdctl /opt/bin/autoscale/kube/bin
    ssh $NODE "mkdir -p ~/kube ; sudo mkdir -p /opt/bin"
    scp -r /opt/bin/autoscale/kube/* $NODE:~/kube/
    ssh $NODE "sudo cp ~/kube/bin/* /opt/bin/ ; \
               sudo cp ~/kube/initd/* /etc/init.d/ ; \
               sudo cp ~/kube/default/* /etc/default ; \
               sudo chmod +x /etc/init.d/etcd /etc/init.d/kubelet \
                           /etc/init.d/kube-proxy /etc/init.d/flanneld"
   echo "Transfer Completed"
}


function run-services() {
    ssh $NODE "sudo service etcd start"
    ssh $NODE "sudo service kubelet start"
    ssh $NODE "sudo service kube-proxy start"
    ssh $NODE "sudo service flanneld start"
    ssh $NODE "sudo bash ~/kube/reconfDocker.sh"
}

ssh-setup

# decide etcd name and add it to etcdctl member list
create-etcd-name
echo "ETCD name..  $ETCD_NAME"
/opt/bin/etcdctl member add $ETCD_NAME http://$NODE_IP:$PORT_ETCD_LISTEN_PEER |tail -n +2  > /tmp/etcd.tmp

source /tmp/etcd.tmp
if [ -z $ETCD_INITIAL_CLUSTER ] ; then
    echo "ETCD member add error"
    exit 1
fi
rm /tmp/etcd.tmp

mkdir -p /opt/bin/autoscale/kube/default

create-etcd-opts
echo "ETCD_OPTS=\"$ETCD_OPTS\"" > /opt/bin/autoscale/kube/default/etcd
create-kube-proxy-opts
echo "KUBE_PROXY_OPTS=\"$KUBE_PROXY_OPTS\"" > /opt/bin/autoscale/kube/default/kube-proxy
create-kubelet-opts
echo KUBELET_OPTS="\"$KUBELET_OPTS\"" > /opt/bin/autoscale/kube/default/kubelet
create-flanneld-opts
echo FLANNEL_OPTS="\"$FLANNEL_OPTS\"" > /opt/bin/autoscale/kube/default/flanneld

transfer-files
run-services

sleep 3

$BIN_KUBECTL label nodes $NODE_IP type=GCE

