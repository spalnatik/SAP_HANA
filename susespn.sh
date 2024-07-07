#!/bin/bash

clientid=$1
clientsecret=$2
rgname=$3
subscriptionID=$4

sudo crm configure primitive rsc_st_azure stonith:fence_azure_arm params subscriptionId="$subscriptionID" resourceGroup="$rgname" tenantId="72f988bf-86f1-41af-91ab-2d7cd011db47" login="$clientid" passwd="$clientsecret" pcmk_monitor_retries=4 pcmk_action_limit=3 power_timeout=240 pcmk_reboot_timeout=900 pcmk_delay_max=15 op monitor interval=3600 timeout=120

sudo crm configure property stonith-timeout=900
