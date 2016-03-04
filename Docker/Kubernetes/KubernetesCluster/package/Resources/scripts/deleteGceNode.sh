#!/bin/bash
# Removes the gce node from k8s cluster

# Args:
# $1: Node IP to delete
# $2: Username of the node

set -e

TEMP_FILE="/tmp/etcd.list"
LOG_FILE="/var/log/gce.log"

NODE_USER=$2
NODE_IP=$1
NODE="$NODE_USER@$NODE_IP"

ETCD_BIN="/opt/bin/etcdctl"
KUBECTL_BIN="/opt/bin/kubectl"

if [ $NODE_IP == "0" ] || [ -z $NODE_IP ] ; then
    echo '{ "error": "No GCE nodes to delete" }'
    exit 0
fi

echo "Removing $NODE_IP from cluster" >> $LOG_FILE

# files to remove from node
function clean-files() {
    ssh $NODE "sudo rm -rf /opt/bin ; rm -rf  ~/kube"
    ssh $NODE "sudo rm -f /etc/init.d/etcd /etc/init.d/kubelet /etc/init.d/kube-proxy /etc/init.d/flanneld"
    ssh $NODE "sudo rm -f /etc/init/etcd.conf /etc/init/kubelet.conf /etc/init/kube-proxy.conf /etc/init/flanneld.conf"
    ssh $NODE "sudo rm -rf /var/lib/etcd"
    ssh $NODE "sudo rm -f /etc/default/etcd /etc/default/kubelet /etc/default/kube-proxy /etc/default/flanneld"

}

# remove this node from etcd member list
function remove-etcd() {
    $ETCD_BIN member list > $TEMP_FILE
    chmod 0666 $TEMP_FILE
    while read -r line
    do
        if [[ $line == *"$NODE_IP:"* ]]
        then
            id=$(echo $line | cut -d ":"  -f 1)
            echo "Deleting ID:$id from Cluster"
            $ETCD_BIN member remove $id
            break
        fi
    done < $TEMP_FILE
    rm $TEMP_FILE
}

# stop the services
function stop-services() {
    ssh $NODE "sudo service kubelet stop"
    ssh $NODE "sudo service kube-proxy stop"
    ssh $NODE "sudo service flanneld stop"
}


# delete this node from kubectl get nodes
$KUBECTL_BIN label nodes $NODE_IP type- || true
$KUBECTL_BIN label nodes $NODE_IP creationType- || true
$KUBECTL_BIN delete nodes $NODE_IP >> $LOG_FILE

remove-etcd >> $LOG_FILE
stop-services >> $LOG_FILE

clean-files

sleep 1
