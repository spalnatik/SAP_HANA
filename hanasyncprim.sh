#!/bin/bash
pkill zypper 
pkill zypper 

zypper --non-interactive --no-refresh install SAPHanaSR

cat << EOF > /drsync.sh
su - hn1adm -c 'HDB start && \
hdbsql -d SYSTEMDB -u SYSTEM -p "Abc@12345678" -i 03 "BACKUP DATA USING FILE ('\'initialbackupSYS\'')" && \
hdbsql -d HN1 -u SYSTEM -p "Abc@12345678" -i 03 "BACKUP DATA USING FILE ('\'initialbackupHN1\'')"'

EOF

chmod +x /drsync.sh
#cd /
#./drsync.sh


