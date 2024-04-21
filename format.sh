#!/bin/bash

/dev/disk/azure/scsi1/lun*

sudo pvcreate /dev/disk/azure/scsi1/lun0
sudo pvcreate /dev/disk/azure/scsi1/lun1
sudo pvcreate /dev/disk/azure/scsi1/lun2
sudo pvcreate /dev/disk/azure/scsi1/lun3

sudo vgcreate vg_hana_data_HN1 /dev/disk/azure/scsi1/lun0 /dev/disk/azure/scsi1/lun1
sudo vgcreate vg_hana_log_HN1 /dev/disk/azure/scsi1/lun2
sudo vgcreate vg_hana_shared_HN1 /dev/disk/azure/scsi1/lun3

sudo lvcreate -i 2 -I 256 -l 100%FREE -n hana_data vg_hana_data_HN1
sudo lvcreate -l 100%FREE -n hana_log vg_hana_log_HN1
sudo lvcreate -l 100%FREE -n hana_shared vg_hana_shared_HN1
sudo mkfs.xfs /dev/vg_hana_data_HN1/hana_data
sudo mkfs.xfs /dev/vg_hana_log_HN1/hana_log
sudo mkfs.xfs /dev/vg_hana_shared_HN1/hana_shared


sudo mkdir -p /hana/data/HN1
sudo mkdir -p /hana/log/HN1
sudo mkdir -p /hana/shared/HN1
# Write down the ID of /dev/vg_hana_data_HN1/hana_data, /dev/vg_hana_log_HN1/hana_log, and /dev/vg_hana_shared_HN1/hana_shared
#sudo blkid

#sudo vi /etc/fstab

echo "/dev/mapper/vg_hana_data_HN1-hana_data /hana/data xfs defaults,nofail 0 2"  >> /etc/fstab
echo "/dev/mapper/vg_hana_log_HN1-hana_log /hana/log xfs defaults,nofail 0 2"  >> /etc/fstab
echo "/dev/mapper/vg_hana_shared_HN1-hana_shared /hana/shared xfs defaults,nofail 0 2"  >> /etc/fstab

sudo mount -a
