#!/bin/bash
cat << EOF > /drsync.sh
su - hn1adm -c 'sapcontrol -nr 00 -function StopWait 600 10 && \
hdbnsutil -sr_register --remoteHost=hn1-db-0 --remoteInstance=03 --replicationMode=sync --name=SITE2 && \
sapcontrol -nr 03 -function StopSystem '
EOF

chmod +x /drsync.sh

cd /

./drsync.sh
## check the status 
#hdbnsutil -sr_state


#exit

lines_to_add="[ha_dr_provider_SAPHanaSR]
provider = SAPHanaSR
path = /usr/share/SAPHanaSR
execution_order = 1
 
[ha_dr_provider_suschksrv]
provider = susChkSrv
path = /usr/share/SAPHanaSR
execution_order = 3
action_on_lost = fence
 
[trace]
ha_dr_saphanasr = info"

# File path to the global file
global="/hana/shared/HN1/global/hdb/custom/config/global.ini"

echo "$lines_to_add" | sudo tee -a "$global"
 
cat << EOF > /etc/sudoers.d/20-saphana
# Needed for SAPHanaSR and susChkSrv Python hooks
hn1adm ALL=(ALL) NOPASSWD: /usr/sbin/crm_attribute -n hana_hn1_site_srHook_*
hn1adm ALL=(ALL) NOPASSWD: /usr/sbin/SAPHanaSR-hookHelper --sid=HN1 --case=fenceMe
EOF
 
su - hn1adm -c 'sapcontrol -nr 00 -function StartSystem'
