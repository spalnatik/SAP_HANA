#!/bin/bash



scp -r /mnt/hanashare/HDB_SERVER_LINUX_X86_64 /

cd /mnt/hanashare/HDB_SERVER_LINUX_X86_64

chmod +x hdbinst
chmod +x hdblcm

pkill zypper
pkill zypper

zypper --non-interactive --no-refresh install libgcc_s1 
zypper --non-interactive --no-refresh install libstdc++6 
zypper --non-interactive --no-refresh install libatomic1 
zypper --non-interactive --no-refresh install insserv-compat
zypper --non-interactive --no-refresh install libtool

chmod +x /HDB_SERVER_LINUX_X86_64/instruntime/sdbrun 

#./hdblcm --ignore=check_signature_file

printf "\n1\n\n\n\nHN1\n03\n\n2\n\n\n\n\n\nAbc@12345678\nAbc@12345678\nAbc@12345678\nAbc@12345678\n\n\n\n\nAbc@12345678\nAbc@12345678\n\ny" | ./hdblcm --ignore=check_signature_file



