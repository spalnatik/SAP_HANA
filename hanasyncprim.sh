#!/bin/bash
pkill zypper 
zypper --non-interactive --no-refresh install SAPHanaSR

cat << EOF > /drsync.sh
su - hn1adm -c 'HDB start && \
hdbsql -d SYSTEMDB -u SYSTEM -p "Abc@12345678" -i 03 "BACKUP DATA USING FILE ('\'initialbackupSYS\'')" && \
hdbsql -d HN1 -u SYSTEM -p "Abc@12345678" -i 03 "BACKUP DATA USING FILE ('\'initialbackupHN1\'')"'
EOF

chmod +x /drsync.sh

./drsync.sh

# copy to secondary node
scp /usr/sap/HN1/SYS/global/security/rsecssfs/data/SSFS_HN1.DAT  hn1-db-1:/usr/sap/HN1/SYS/global/security/rsecssfs/data/
scp /usr/sap/HN1/SYS/global/security/rsecssfs/key/SSFS_HN1.KEY  hn1-db-1:/usr/sap/HN1/SYS/global/security/rsecssfs/key/
#Enable 
hdbnsutil -sr_enable --name=SITE1

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
