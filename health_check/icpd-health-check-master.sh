#!/bin/bash
#run only on master nodes


setup() {
    . $UTIL_DIR/util.sh
    #commonly used func are inside of util.sh
    CONFIG_DIR=$INSTALL_PATH

    #TEMP_DIR=$OUTPUT_DIR
    PRE_STR=$(get_prefix)

    LOG_FILE="/tmp/icp_checker.log"
    echo
    echo =============================================================
    echo
    echo Running heath check on ICP for Data ...
    #echo ICP Version: $PRODUCT_VERSION
    #echo Release Date: $RELEASE_DATE
    echo =============================================================
}

health_check() {
    local temp_dir=$1
    all_nodes=`get_master_nodes $CONFIG_DIR|awk '{print $1}'; get_worker_nodes $CONFIG_DIR|awk '{print $1}'`

        echo
        echo Checking node availability...
        echo ------------------------
        for i in `echo $all_nodes`
        do
            ping -w 30 -c 1 $i > /dev/null
            if [ $? -eq 0 ]; then
               echo -e Ping to node $i ${COLOR_GREEN}\[OK\]${COLOR_NC}
            else 
               echo -e Ping to node $i ${COLOR_RED}\[FAILED\]${COLOR_NC}
            fi
        done

        echo
        echo Checking node accessible with ssh...
        echo ------------------------
        for i in `echo $all_nodes`
        do
            ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PasswordAuthentication=no \
                -o ConnectTimeout=10 -Tn $i exit > /dev/null 2>&1
            if [ $? -eq 0 ]; then
               echo -e SSH to node $i ${COLOR_GREEN}\[OK\]${COLOR_NC}
            else 
               echo -e SSH to node $i ${COLOR_RED}\[FAILED\]${COLOR_NC}
            fi
        done

        echo
        echo Checking Docker status...
        echo ------------------------
        for i in `echo $all_nodes`
        do
            ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PasswordAuthentication=no \
                -o ConnectTimeout=10 -Tn $i "systemctl status docker|egrep 'Active:'|egrep 'running'" > /dev/null 2>&1
            if [ $? -eq 0 ]; then
               echo -e Docker status on node $i ${COLOR_GREEN}\[OK\]${COLOR_NC}
            else 
               echo -e Docker status on node $i ${COLOR_RED}\[FAILED\]${COLOR_NC}
            fi
        done

        echo
        echo Checking Kubelet status...
        echo ------------------------
        for i in `echo $all_nodes`
        do
            ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o PasswordAuthentication=no \
                -o ConnectTimeout=10 -Tn $i "systemctl status kubelet|egrep 'Active:'|egrep 'running'" > /dev/null 2>&1
            if [ $? -eq 0 ]; then
               echo -e Kubelet status on node $i ${COLOR_GREEN}\[OK\]${COLOR_NC}
            else 
               echo -e Kubelet status on node $i ${COLOR_RED}\[FAILED\]${COLOR_NC}
            fi
        done

        echo
        echo Checking node status...
        echo ------------------------
        down_node_count=$(kubectl get nodes --no-headers|egrep -vw 'Ready'|wc -l)
        if [ $down_node_count -gt 0 ]; then
            echo -e Not all nodes are ready ${COLOR_RED}\[FAILED\]${COLOR_NC}
            kubectl get nodes
            #exit 1
        else
            echo -e All nodes are ready ${COLOR_GREEN}\[OK\]${COLOR_NC}
        fi

        echo
        echo Checking PVCs on all namespaces...
        echo ------------------------
        down_pvc_count=$(kubectl get pvc --all-namespaces --no-headers|egrep -vw 'Bound|Available'|wc -l)
        if [ $down_pvc_count -gt 0 ]; then
            echo -e Not all PVCs are healthy ${COLOR_RED}\[FAILED\]${COLOR_NC}
            kubectl get pvc --all-namespaces
            #exit 1
        else
            echo -e All PVCs are healthy ${COLOR_GREEN}\[OK\]${COLOR_NC}
        fi

        echo
        echo Checking gluster volumes...
        echo ------------------------
        down_gluster_count=$(gluster volume info|egrep "Status:"|egrep -vw 'Started'|wc -l)
        if [ $down_gluster_count -gt 0 ]; then
            echo -e Not all gluster volumes are started ${COLOR_RED}\[FAILED\]${COLOR_NC}
            gluster volume info|egrep "Status:"
            #exit 1
        else
            echo -e All gluster volumes are started ${COLOR_GREEN}\[OK\]${COLOR_NC}
        fi

        echo
        echo Checking pod status...
        echo ------------------------
        down_pod_count=$(kubectl get pods --all-namespaces --no-headers|egrep -vw 'Running|Completed'|wc -l)
        if [ $down_pod_count -gt 0 ]; then
            echo -e Not all pods are ready ${COLOR_RED}\[FAILED\]${COLOR_NC}
            kubectl get pods --all-namespaces | egrep -v 'Running|Complete'
            #exit 1
        else
            echo -e All pods are ready ${COLOR_GREEN}\[OK\]${COLOR_NC}
        fi
}

check_log_file_exist() {
        local log_file=$1
        local name=$2
        if [ -f $log_file ]; then
                print_passed_message "$name collected: $log_file"
        else
                print_failed_message "failed to collect $name"
        fi
}

health_check_by_cmd(){
        local temp_dir=$1
        local name=$2
        local cmd=$3
        local log_file=$temp_dir"/$name"
        $cmd > $log_file
        check_log_file_exist $log_file $name
}

TEMP_DIR=$1
setup
sanity_checks
health_check
