#!/bin/bash
# Detects which nodes to delete

# $0 add ipAddr app instanceName
# $0 add ipAddr man
# $0 remove

new_nodes_list_file=/etc/autoscale/gcpApp.list
existing_nodes_list_file=/etc/autoscale/gcpMan.list
TEMP_FILE=tmp

ACTION=$1
IP=$2
NODE_TYPE=$3 # new | existing
NAME=$4

if [ ! -f $new_nodes_list_file ]; then
    touch $new_nodes_list_file
fi
if [ ! -f $existing_nodes_list_file ]; then
    touch $existing_nodes_list_file
fi

# checkthe node is added by autoscale service or not
AUTO_FLAG_FILE="/tmp/autoscale"
if [ ! -f $AUTO_FLAG_FILE ] ; then
    AUTO_FLAG=0
else
    AUTO_FLAG=`cat $AUTO_FLAG_FILE`
fi

# If node node is added manually from UI, set that node as static. And don't delete static 
# nodes by autoscale service
if [ $AUTO_FLAG == "1" ]  ; then
    CREATION="auto"
else
    CREATION="static"
fi

# Write the nodes to file. Helps to delete the last node later
if [ $ACTION == "add" ] && [ $NODE_TYPE == "new" ] ; then
    echo "$IP;$CREATION;$NAME" >> $new_nodes_list_file
    exit 0
elif [ $ACTION == "add" ] && [ $NODE_TYPE == "existing" ] ; then
    echo "$IP;$CREATION;" >> $existing_nodes_list_file
    exit 0
fi

# Search and delete the record of last node that is created by autoscale service
function autoDelete()
{
    file=$1
    count=`wc -l $file | awk '{print $1}'`
    while [ $count -gt 0 ]; do
      line=`awk "NR==$count" $file`
      if [[ "$line" == *"auto"* ]]; then
        instanceName=`echo $line | cut -f 3 -d ";"`
        echo "$instanceName" > /tmp/deleteGCENode
        echo $line | cut -f 1 -d ";"
        sed $line"d" $file > $file.new
        mv $file.new $file
        break
      fi
      ((count=count-1))
    done
}

# Search and delete the record of last node that is created manually
function staticDelete()
{
    file=$1
    count=`wc -l $file | awk '{print $1}'`
    while [ $count -gt 0 ]; do
      line=`awk "NR==$count" $file`
      if [[ "$line" == *"static"* ]]; then
        instanceName=`echo $line | cut -f 3 -d ";"`
        echo "$instanceName" > /tmp/deleteGCENode
        echo $line | cut -f 1 -d ";"
        sed $count"d" $file > $file.new
        mv $file.new $file
        break
      fi
      ((count=count-1))
    done
}

if [ $1 == "remove" ] && [ $AUTO_FLAG == "1" ] ; then
    ip=`autoDelete $new_nodes_list_file`
    if [ -z $ip ] ; then
       ip=`autoDelete $existing_nodes_list_file`
    fi
    echo $ip
elif [ $1 == "remove" ] ; then
    ip=`staticDelete $new_nodes_list_file`
    if [ -z $ip ] ; then
       ip=`staticDelete $existing_nodes_list_file`
    fi
    echo $ip
fi


# returns total GCE node in Cluster
if [ $ACTION == "busy_count" ] ; then
    new_nodes_count=`wc -l $new_nodes_list_file | awk '{print $1}'`
    existing_nodes_count=`wc -l $existing_nodes_list_file | awk '{print $1}'`
    ((total_nodes=new_nodes_count+existing_nodes_count))
    echo $total_nodes
fi

# return how many nodes are added to cluster using autoscale service
if [ $ACTION == "auto_busy_node" ] ; then
    new_nodes_count=`grep -c ";auto;" $new_nodes_list_file`
    existing_nodes_count=`grep -c ";auto;" $existing_nodes_list_file`
    ((total_nodes=new_nodes_count+existing_nodes_count))
    echo $total_nodes
fi
