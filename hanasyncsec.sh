#!/bin/bash
pkill zypper 
pkill zypper 

zypper --non-interactive --no-refresh install SAPHanaSR

cat << EOF > /drsync.sh
su - hn1adm -c 'sapcontrol -nr 03 -function StopWait 600 10 && \
hdbnsutil -sr_register --remoteHost=hn1-db-0 --remoteInstance=03 --replicationMode=sync --name=SITE2 && \
sapcontrol -nr 03 -function StopSystem '
EOF

chmod +x /drsync.sh

#cd /

#./drsync.sh
## check the status 
#hdbnsutil -sr_state


#exit

