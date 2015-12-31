#!/usr/bin/python3
import json
import sys
import urllib.request
import time
import numpy
import os
import signal
import configparser
import subprocess
from datetime import datetime

data_file = "/etc/autoscale/autoscale.conf"
scale_script = "/opt/bin/autoscale/scale.sh"
MAX_VMS_LIMIT = 0
MIN_VMS_LIMIT = 0
MAX_GCE_VMS_LIMIT = 0
MIN_GCE_VMS_LIMIT = 0
MAX_CPU_LIMIT = 0
MIN_CPU_LIMIT = 0
CUR_NODES_COUNT = 0
POLLING_CLUSTER_PERIOD = 15
NODES_OBJ = {}
ALL_NODES={} # { "nodeIP" { "cpu" : 40, "auto": True } }
MAX_HYSTERESIS_COUNT = 6
CUR_HYSTERESIS = { "count": 0, "sample_type": None } # { sample_type="scaleUp" or "scaleDown" }
UPDATED_NODES_LIST=[]

# Parsing input parameters from autoscale.conf
def get_params():
    global MAX_VMS_LIMIT, MIN_VMS_LIMIT, MIN_GCE_VMS_LIMIT
    global MAX_GCE_VMS_LIMIT, MAX_CPU_LIMIT, MIN_CPU_LIMIT, MASTER
    configParser = configparser.ConfigParser()
    configParser.read(data_file)
    MASTER = configParser.get('DEFAULT', 'MASTER')
    MAX_VMS_LIMIT = int(configParser.get('DEFAULT', 'max_vms_limit'))
    MIN_VMS_LIMIT = int(configParser.get('DEFAULT', 'min_vms_limit'))
    MAX_CPU_LIMIT = int(configParser.get('DEFAULT', 'MAX_CPU_LIMIT'))
    MIN_CPU_LIMIT = int(configParser.get('DEFAULT', 'MIN_CPU_LIMIT'))
    try:
        MAX_GCE_VMS_LIMIT = int(configParser.get('GCE', 'gcp_minion_nodes'))
    except Exception as e:
        MAX_GCE_VMS_LIMIT = 0


def get_cpu_usage(node_ip):
    api = "http://"+node_ip+":4194/api/v1.3/machine"
    request = urllib.request.Request(api)
    response = urllib.request.urlopen(request)
    decode_response = (response.read().decode('utf-8'))
    string = str(decode_response)
    machine_info = json.loads(string)
    num_cores = machine_info["num_cores"]

    api = "http://"+node_ip+":4194/api/v1.3/containers/"
    request = urllib.request.Request(api)
    response = urllib.request.urlopen(request)
    decode_response = (response.read().decode('utf-8'))
    string = str(decode_response)
    containers_info = json.loads(string)
    len_stats = len(containers_info["stats"])
    len_stats = int(len_stats)
    cur_stats = len_stats - 1
    prev_stats = len_stats - 2
    cur_status = containers_info["stats"][cur_stats]
    prev_status = containers_info["stats"][prev_stats]
    cur_cpu_usage = cur_status["cpu"]["usage"]["total"]
    cur_timestamp = cur_status["timestamp"]
    prev_cpu_usage = prev_status["cpu"]["usage"]["total"]
    prev_timestamp = prev_status["timestamp"]
    cur_time = numpy.datetime64(cur_timestamp).astype(datetime)
    prev_time = numpy.datetime64(prev_timestamp).astype(datetime)
    raw_cpu_usage = cur_cpu_usage - prev_cpu_usage
    try:
        interval_ns = cur_time - prev_time
    except Exception as e:
        return False
    if interval_ns != 0:
        cpu_usage = raw_cpu_usage/interval_ns
    else:
        return False
    cpu_usage = cpu_usage/num_cores * 100
    cpu_usage = '%.f' % round(cpu_usage, 1)
    cpu_usage = int(cpu_usage)
    if (cpu_usage > 100):
        cpu_usage = 100
    return cpu_usage


# retuns True, if cluster is ready.
def get_k8s_status():
    api = "http://"+MASTER+":8080"
    request = urllib.request.Request(api)
    try:
        response = urllib.request.urlopen(request)
        if response.status == 200:
            print("OK")
            return True
    except Exception as e:
        print("not OK")
        print(e)
        return False


def get_total_nodes():
    global NODES_OBJ,UPDATED_NODES_LIST
    api = "http://"+MASTER+":8080/api/v1/nodes"
    request = urllib.request.Request(api)
    response = urllib.request.urlopen(request)
    decode_response = (response.read().decode('utf-8'))
    string = str(decode_response)
    nodes_info = json.loads(string)
    NODES_OBJ = nodes_info
    try:
        number_minions = len(nodes_info["items"])
        UPDATED_NODES_LIST=[]
        for i in range(0,number_minions):
              UPDATED_NODES_LIST.append(NODES_OBJ["items"][i]["metadata"]["name"])
        return number_minions
    except Exception as e:
        return -1

def get_private_nodes(total):
    return total-get_gcp_nodes()


def get_gcp_nodes():
    if MAX_GCE_VMS_LIMIT == 0:
        return 0
    # gce_nodes=os.system("sudo ./gceIpManger.sh busy_count")
    # print(gce_nodes)
    gceIpManager = "/opt/bin/autoscale/gceIpManager.sh"
    cmd = "sudo bash "+gceIpManager+" busy_count"
    output = subprocess.check_output(cmd, shell=True)
    return int(output)


def print_limits():
    print ("Max VMs in Cluster: ", MAX_VMS_LIMIT)
    print ("Min VMs in Cluster: ", MIN_VMS_LIMIT)
    print ("Max GCE VMs Limit: ", MAX_GCE_VMS_LIMIT)
    print ("Min GCE VMs Limit: ", MIN_GCE_VMS_LIMIT)
    print ("Max CPU Usage Limit: ", MAX_CPU_LIMIT)
    print ("Min CPU Usage Limit: ", MIN_CPU_LIMIT, "\n")


def is_node_ready(minion):
    try:
        if NODES_OBJ["items"][minion]["status"]["conditions"][0]["status"] != \
           "True":
            return False
    except Exception as e:
        return False
    return True

def is_auto_created(minion):
    if "type" in NODES_OBJ["items"][minion]["metadata"]["labels"]:
        if "creationType" in NODES_OBJ["items"][minion]["metadata"]["labels"]:
            return True
        else:
            return False
    else:
        return True
   


def update_removed_nodes():
    removed_nodes=[]
    global UPDATED_NODES_LIST, ALL_NODES, CUR_HYSTERESIS
    for n in ALL_NODES:
        if n not in UPDATED_NODES_LIST:
            removed_nodes.append(n)
    for n in removed_nodes:
        del ALL_NODES[n]
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        print (timestamp + " - " + n + " node removed from cluster")
        CUR_HYSTERESIS["count"] = 0

def scaleUpNodes():
    if (private_nodes < MAX_VMS_LIMIT):
        # Private Scale up
        print("Scaling up private")
        os.system(scale_script + ' up')
        return True
    elif (get_gcp_nodes() < MAX_GCE_VMS_LIMIT):
        # GCE Scale UP
        print("private nodes limit has been reached")
        print("Scaling up GCE")
        os.system(scale_script + ' up gce')
        return True
    else:
        # Max reached
        print("Max nodes have been reached")
        return False


def scaleDownNodes():
    if (get_gcp_nodes() > MIN_GCE_VMS_LIMIT):
        # GCE Scale Down
        gceIpManager = "/opt/bin/autoscale/gceIpManager.sh"
        cmd = "sudo bash "+gceIpManager+" auto_busy_node"
        output = subprocess.check_output(cmd, shell=True)
        output=output.decode("utf-8")[:-1]
        if (output != "0"):
            print("GCE Scale Down")
            os.system(scale_script + ' down gce')
            return True
    if (private_nodes > MIN_VMS_LIMIT):
        # Private Scale down
        print("Private Scale down")
        os.system(scale_script + ' down')
        return True
    else:
        # Already Min
        # print("Min nodes have been reached")
        return False

get_params()
print("Waiting for Cluster")
while (get_k8s_status() is not True):
    time.sleep(1)
print("cluster is up")
time.sleep(20)
print_limits()

while 1:
    total_minions = get_total_nodes()
    if (total_minions == -1):
        time.sleep(3)
        continue
    minion = 0
    update_removed_nodes()
    while minion < total_minions:
        node_ip = NODES_OBJ["items"][minion]["metadata"]["name"]
     
        if (is_node_ready(minion) is False):
            minion += 1
            time.sleep(3)
            continue
        # print("monitoring minion: ", node_ip)
        minion += 1

        cpu_usage = get_cpu_usage(node_ip)
        if(cpu_usage is False):
            time.sleep(3)
            continue
        if node_ip not in ALL_NODES:
           timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
           print (timestamp + " - "+"Started monitoring node " + node_ip)
           CUR_HYSTERESIS["count"] = 0
           time.sleep(POLLING_CLUSTER_PERIOD)
           if is_auto_created(minion-1):
               ALL_NODES[node_ip] = { "cpu": cpu_usage,"auto": True }
           else:
               ALL_NODES[node_ip] = { "cpu": cpu_usage,"auto": False }
        
        ALL_NODES[node_ip]["cpu"] = cpu_usage
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        print (timestamp + " - CPU usage of "+node_ip+" :", cpu_usage)
        time.sleep(2)

    private_nodes = get_private_nodes(total_minions)
    if not ALL_NODES:
        CUR_HYSTERESIS["count"]=0
        time.sleep(POLLING_CLUSTER_PERIOD)
        continue
    AUTO_CREATED_NODES = dict((node,details) for node, details in ALL_NODES.items() if details["auto"])
    if all(MAX_CPU_LIMIT > v['cpu'] > MIN_CPU_LIMIT for v in ALL_NODES.values()):
        # All nodes in within threshold level
        CUR_HYSTERESIS["count"] = 0
        time.sleep(POLLING_CLUSTER_PERIOD)
        continue
    elif any(v['cpu'] < MIN_CPU_LIMIT for v in ALL_NODES.values()) and \
        any(v['cpu'] > MAX_CPU_LIMIT for v in ALL_NODES.values()):
            # Some nodes are above max and below min threshold
            CUR_HYSTERESIS["count"] = 0
            time.sleep(POLLING_CLUSTER_PERIOD)
            continue
    elif any(v['cpu'] > MAX_CPU_LIMIT for v in ALL_NODES.values()):
        if CUR_HYSTERESIS["sample_type"] != "scaleUp":
            CUR_HYSTERESIS["sample_type"] = "scaleUp"
            CUR_HYSTERESIS["count"] = 1
        elif CUR_HYSTERESIS["count"] == MAX_HYSTERESIS_COUNT:
            if scaleUpNodes():
                CUR_HYSTERESIS["count"] = 0
        else:
            CUR_HYSTERESIS["count"] = CUR_HYSTERESIS["count"] + 1
    elif any(v['cpu'] < MIN_CPU_LIMIT for v in AUTO_CREATED_NODES.values()):
        if CUR_HYSTERESIS["sample_type"] != "scaleDown":
            CUR_HYSTERESIS["sample_type"] = "scaleDown"
            CUR_HYSTERESIS["count"] = 1
        elif CUR_HYSTERESIS["count"] == MAX_HYSTERESIS_COUNT:
            if scaleDownNodes():
                CUR_HYSTERESIS["count"] = 0
        else:
            CUR_HYSTERESIS["count"] = CUR_HYSTERESIS["count"] + 1
    time.sleep(POLLING_CLUSTER_PERIOD)
