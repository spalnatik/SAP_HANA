#!/bin/bash

disk=`ls -l /dev/disk/by-id/scsi-* | grep sdc | awk 'NR==2 {print $9}'`

sed -i "s|^#SBD_DEVICE=.*|SBD_DEVICE=\"$disk\"|" /etc/sysconfig/sbd

echo softdog | sudo tee /etc/modules-load.d/softdog.conf

sudo modprobe -v softdog
