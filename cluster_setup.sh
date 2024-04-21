#!/bin/bash

#This script is used to setup the cluster and update the OS config to make sure that they are matching the requirements for Azure Env

LOGFILE='/var/log/azure/cluster_setup_log'
exec >> $LOGFILE
exec 2>&1

echo '=================================='
date
source /etc/os-release
SUSE_VER=`echo $VERSION | cut -d '-' -f1 `

function apply_sles12_recommend()
{
    pkill zypper
    pkill zypper
    zypper --non-interactive --no-refresh install socat
    zypper --non-interactive --no-refresh install resource-agents
    zypper --non-interactive --no-refresh install fence-agents
    zypper --non-interactive --no-refresh install bc
    resouce_agent_minor_version=`zypper --no-refresh info resource-agents | grep -i version | awk '{print $NF}' | cut -d '-' -f2 | rev | cut -c3- | rev`
    recommended_resouce_agent_version='3.30'
    #result=`echo $resouce_agent_minor_version '>' $recommended_resouce_agent_version | bc -l`
    result=1
    if [ $result ]
    then
        echo 'the installed resouce agent is higher than recommended version, will continue ..'
    else
        echo 'Cannot find resouce agents higher than recommended , check repo'
        exit 3
    fi
    echo 'Updating the DefaultTasksMax to be more than 512'
    echo 'DefaultTasksMax=4096' >> /etc/systemd/system.conf
    systemctl daemon-reload
    echo 'DefaultTasksMax is updated and the new value is :'
    systemctl --no-pager show | grep DefaultTasksMax
    echo 'Updating memory settings for the VMs ..'
    echo 'vm.dirty_bytes = 629145600' >> /etc/sysctl.conf
    echo 'vm.dirty_background_bytes = 314572800' >> /etc/sysctl.conf
    sysctl -p 
    echo 'Checking on cloud-netconfig-azure if it is higher than 1.3'
    netconfig_version=`zypper info cloud-netconfig-azure | grep -i version | awk '{print $NF}' | cut -d '-' -f1`
    result1=`echo $netconfig_version '>' "1.3" | bc -l`
    if [ $result1 ]
    then
        echo 'netconfig version is higher than 1.3 no further actions needed'
    else
        echo 'netconfig version is less than 1.3, updating network file ..'
        sed -i "s/CLOUD_NETCONFIG_MANAGE='yes'/CLOUD_NETCONFIG_MANAGE='no'/g" /etc/sysconfig/network/ifcfg-eth0
    fi
    SUSEConnect -p sle-module-public-cloud/12/x86_64
    sudo zypper --non-interactive --no-refresh install python-azure-mgmt-compute
}


function apply_sles15_recommend()
{
    pkill zypper
    pkill zypper
    zypper --non-interactive --no-refresh install socat
    zypper --non-interactive --no-refresh install resource-agents
    zypper --non-interactive --no-refresh install fence-agents
    zypper --non-interactive --no-refresh install bc
    resouce_agent_minor_version=`zypper info resource-agents | grep -i version | awk '{print $NF}' | cut -d '-' -f2 | rev | cut -c3- | rev`
    recommended_resouce_agent_version='4.3'
    #result=`echo $resouce_agent_minor_version '>' $recommended_resouce_agent_version | bc -l`
    result=1
    if [ $result ]
    then
        echo 'the installed resouce agent is higher than recommended version, will continue ..'
    else
        echo 'Cannot find resouce agents higher than recommended , check repo'
        exit 3
    fi
    SUSEConnect -p sle-module-public-cloud/15.1/x86_64
    sudo zypper --non-interactive --no-refresh install python3-azure-mgmt-compute
}


if [ $SUSE_VER == '12' ]
then
    apply_sles12_recommend
else
    apply_sles15_recommend
fi

hostname=`hostname`
echo "We are on node $hostname"
if [ $hostname == 'hn1-db-0' ]
then
    echo 'Starting configuring the cluster now ..'
    ha-cluster-init -u -y -n test-cluster -N hn1-db-1
    echo 'Updateing the token for the proper values, but first we will take backup ..'
    cp /etc/corosync/corosync.conf /etc/corosync/corosync.conf_old
    sed -i 's/^\ttoken\:.*$/\ttoken\: 30000/' /etc/corosync/corosync.conf
    sed -i 's/^\tconsensus\:.*$/\tconsensus\: 36000/' /etc/corosync/corosync.conf
    csync2 -xv
    csync2 -xv

    echo 'Now we are ready to configure the resouces ..'
    crm configure rsc_defaults resource-stickiness="200"

else
    echo "we are on $hostname, nothing to do"
fi
