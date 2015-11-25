#!/bin/bash
# $1 - free_node | busy_node | details
#

function usage()
{
    echo ""
    echo "Usage: $0 [free_node|busy_node|details]"
    echo "Options: "
    echo ""
    echo "    free_node:   returns first available GCP node IP, 0 if all nodes busy "
    echo ""
    echo "    busy_node:   returns the last used GCP node IP, 0 if all nodes free"
    echo ""
    echo "    details:      returns detail json format"
    echo ""
    echo "Returns -1 if GCP nodes not specified in conf file"
    echo ""

}


if [ $# -ne 1 ] ; then
    usage
    exit 1
fi

option=$1

if [ $option != "free_node" ] && [ $option != "busy_node" ] && [ $option != "details" ] && [ $option != "busy_count" ]
then
    echo "Unkown Option: $option"
    usage
    exit 1
fi

conf_file="/etc/autoscale/autoscale.conf"
if [ ! -f $conf_file ] ; then
    echo "-1"
    exit 0
fi

gcp_nodes=$(awk -F "=" '/^gcp_ip/ {print $2}' $conf_file)

# if gcp_nodes are not available
if [ -z $gcp_nodes ] ; then
    echo "-1"
    exit 0
fi

#json=$(cat tmp)
json=`curl -s localhost:8080/api/v1/nodes`
total_nodes=$(echo $json | jq --raw-output ".items | length")
node_name=$(echo $json | jq --raw-output ".items[0].metadata.name")

GCP_ARRAY=()
count=0

function create_gcp_array()
{
    while IFS=',' read -ra ADDR; do
        for i in "${ADDR[@]}"; do
            GCP_ARRAY+=("$i")
        done
    done <<< "$gcp_nodes"
}

function print_gcp_array()
{
    for each in "${GCP_ARRAY[@]}"
    do
        echo "$each"
    done
}

# return 0 - if available, otherwise -1
function is_node_available()
{
    gcp_node=$1
    count=0
    while [ $count -lt $total_nodes ] ; do
        node_name=$(echo $json | jq --raw-output ".items[$count].metadata.name")
        if [ $node_name == $gcp_node ] ; then
            echo "-1"
            return;
        fi
        let count=count+1
    done
    count=0
    echo "0"
}

function get_free_node()
{
    for node in "${GCP_ARRAY[@]}"
    do
        ret=$(is_node_available $node)
        if [ $ret == "0" ] ; then
            echo $node
            return;
        fi
    done
    echo "0"
}

# returns last busy node
function get_busy_node()
{
    #check first node is busy
    first_node=${GCP_ARRAY[0]}
    ret=$(is_node_available $first_node)
    if [ $ret == "0" ] ; then
        echo "0"
        return;
    fi

    prev_node=$first_node
    for node in "${GCP_ARRAY[@]}"
    do
        ret=$(is_node_available $node)
        if [ $ret == "0" ] ; then
            echo $prev_node
            return;
        fi
        prev_node=$node
    done

    # all busy. Return last one
    echo ${GCP_ARRAY[-1]}
}

function details()
{
    total_gcp_nodes=${#GCP_ARRAY[@]}
    first_node=${GCP_ARRAY[0]}
    ret=$(is_node_available $first_node)
    if [ $ret == "0" ] ; then
       busy_nodes=0
    fi

    if [ -z $busy_nodes ] ; then
        prev_node=$first_node
        for node in "${GCP_ARRAY[@]}"
        do
            ret=$(is_node_available $node)
            if [ $ret == "0" ] ; then
                break;
            fi
            prev_node=$node
            let busy_nodes=busy_nodes+1
        done
    fi
    echo "{"
    echo "\"nodes_list\": \"$gcp_nodes\","
    echo "\"total_nodes_count\": \"$total_gcp_nodes\","
    echo "\"busy_nodes_count\": \"$busy_nodes\""
    echo "}"

}

create_gcp_array

if [ $option == "free_node" ] ; then
   get_free_node
   exit 0
fi
if [ $option == "busy_node" ] ; then
   get_busy_node
   exit 0
fi
if [ $option == "details" ] ; then
   details
   exit 0
fi
if [ $option == "busy_count" ] ; then
  json=`details`
  echo $json | jq --raw-output ".busy_nodes_count"
  exit 0
fi

