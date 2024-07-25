#!/bin/bash
rgname=$1
subscriptionID=$2

sudo crm configure primitive rsc_st_azure stonith:fence_azure_arm \
params msi=true subscriptionId="$subscriptionID" resourceGroup="$rgname" \
pcmk_monitor_retries=4 pcmk_action_limit=3 power_timeout=240 pcmk_reboot_timeout=900 pcmk_delay_max=15  \
op monitor interval=3600 timeout=120

sudo crm configure property stonith-timeout=900
