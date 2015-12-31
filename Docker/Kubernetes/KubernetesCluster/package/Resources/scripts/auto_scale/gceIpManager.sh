#!/bin/bash

# $0 add ipAddr app instanceName
# $0 add ipAddr man
# $0 remove

gcp_app_list_file=/etc/autoscale/gcpApp.list
gcp_man_list_file=/etc/autoscale/gcpMan.list
TEMP_FILE=tmp

ACTION=$1
IP=$2
NODE_TYPE=$3 # app or man
NAME=$4

if [ ! -f $gcp_app_list_file ]; then
    touch $gcp_app_list_file
fi
if [ ! -f $gcp_man_list_file ]; then
    touch $gcp_man_list_file
fi

AUTO_FLAG_FILE="/tmp/autoscale"
if [ ! -f $AUTO_FLAG_FILE ] ; then
    AUTO_FLAG=0
else
    AUTO_FLAG=`cat $AUTO_FLAG_FILE`
fi

if [ $AUTO_FLAG == "1" ]  ; then
    CREATION="auto"
else
    CREATION="static"
fi

if [ $ACTION == "add" ] && [ $NODE_TYPE == "app" ] ; then
    echo "$IP;$CREATION;$NAME" >> $gcp_app_list_file
    exit 0
elif [ $ACTION == "add" ] && [ $NODE_TYPE == "man" ] ; then
    echo "$IP;$CREATION;" >> $gcp_man_list_file
    exit 0
fi

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
    ip=`autoDelete $gcp_app_list_file`
    if [ -z $ip ] ; then
       ip=`autoDelete $gcp_man_list_file`
    fi
    echo $ip
elif [ $1 == "remove" ] ; then
    ip=`staticDelete $gcp_app_list_file`
    if [ -z $ip ] ; then
       ip=`staticDelete $gcp_man_list_file`
    fi
    echo $ip
fi

if [ $ACTION == "busy_count" ] ; then
    app_node_count=`wc -l $gcp_app_list_file | awk '{print $1}'`
    man_node_count=`wc -l $gcp_man_list_file | awk '{print $1}'`
    ((total_nodes=app_node_count+man_node_count))
    echo $total_nodes
fi

if [ $ACTION == "auto_busy_node" ] ; then
    app_node_count=`grep -c ";auto;" $gcp_app_list_file`
    man_node_count=`grep -c ";auto;" $gcp_man_list_file`
    ((total_nodes=app_node_count+man_node_count))
    echo $total_nodes
fi
