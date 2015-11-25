#!/bin/bash
# Removes the gcp node from k8s cluster

set -e

GCP_FILE="/opt/bin/autoscale/gceIpManager.sh"
conf_file="/etc/autoscale/autoscale.conf"
TEMP_FILE="/tmp/etcd.list"
HORIZON_LOG="/tmp/autoscale.log"

NODE_USER=$(awk -F "=" '/^gcp_username/ {print $2}' $conf_file)
NODE_IP=$(bash $GCP_FILE busy_node)
NODE="$NODE_USER@$NODE_IP"

ETCD_BIN="/opt/bin/etcdctl"
KUBECTL_BIN="/opt/bin/kubectl"

if [ $NODE_IP == "0" ] ; then
    echo '{ "error": "No GCE nodes to delete" }'
    exit 0
fi


# files to remove from node
function clean-files() {
    ssh $NODE "sudo rm -rf /opt/bin ; rm -rf  ~/kube"
    ssh $NODE "sudo rm -f /etc/init.d/etcd /etc/init.d/kubelet /etc/init.d/kube-proxy /etc/init.d/flanneld"
    ssh $NODE "sudo rm -rf /var/lib/etcd"
    ssh $NODE "sudo rm -f /etc/default/etcd /etc/default/kubelet /etc/default/kube-proxy /etc/default/flanneld"

}

# remove this node from etcd member list
function remove-etcd() {
    $ETCD_BIN member list > $TEMP_FILE
    chmod 0666 $TEMP_FILE
    while read -r line
    do
        name=$line
        if [[ $line == *"$NODE_IP:"* ]]
        then
            id=`echo $line | cut -d ":"  -f 1`
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
$KUBECTL_BIN label nodes $NODE_IP type-
$KUBECTL_BIN delete nodes $NODE_IP

remove-etcd
stop-services

clean-files

# To settle down the cluster noise
sleep 5

