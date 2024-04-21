#!/bin/bash

sudo crm configure property maintenance-mode=true

# Replace <placeholders> with your instance number and HANA system ID

sudo crm configure primitive rsc_SAPHanaTopology_HN1_HDB03 ocf:suse:SAPHanaTopology \
  operations \$id="rsc_sap2_HN1_HDB03-operations" \
  op monitor interval="10" timeout="600" \
  op start interval="0" timeout="600" \
  op stop interval="0" timeout="300" \
  params SID="HN1" InstanceNumber="03"

sudo crm configure clone cln_SAPHanaTopology_HN1_HDB03 rsc_SAPHanaTopology_HN1_HDB03 \
  meta clone-node-max="1" target-role="Started" interleave="true"


# Replace <placeholders> with your instance number, HANA system ID, and the front-end IP address of the Azure load balancer. 

sudo crm configure primitive rsc_SAPHana_HN1_HDB03 ocf:suse:SAPHana \
  operations \$id="rsc_sap_HN1_HDB03-operations" \
  op start interval="0" timeout="3600" \
  op stop interval="0" timeout="3600" \
  op promote interval="0" timeout="3600" \
  op monitor interval="60" role="Master" timeout="700" \
  op monitor interval="61" role="Slave" timeout="700" \
  params SID="HN1" InstanceNumber="03" PREFER_SITE_TAKEOVER="true" \
  DUPLICATE_PRIMARY_TIMEOUT="7200" AUTOMATED_REGISTER="false"

sudo crm configure ms msl_SAPHana_HN1_HDB03 rsc_SAPHana_HN1_HDB03 \
  meta notify="true" clone-max="2" clone-node-max="1" \
  target-role="Started" interleave="true"

sudo crm resource meta msl_SAPHana_HN1_HDB03 set priority 100

sudo crm configure primitive rsc_ip_HN1_HDB03 ocf:heartbeat:IPaddr2 \
  meta target-role="Started" \
  operations \$id="rsc_ip_HN1_HDB03-operations" \
  op monitor interval="10s" timeout="20s" \
  params ip="10.0.0.4"

sudo crm configure primitive rsc_nc_HN1_HDB03 azure-lb port=62503 \
  op monitor timeout=20s interval=10 \
  meta resource-stickiness=0

sudo crm configure group g_ip_HN1_HDB03 rsc_ip_HN1_HDB03 rsc_nc_HN1_HDB03

sudo crm configure colocation col_saphana_ip_HN1_HDB03 4000: g_ip_HN1_HDB03:Started \
  msl_SAPHana_HN1_HDB03:Master  

sudo crm configure order ord_SAPHana_HN1_HDB03 Optional: cln_SAPHanaTopology_HN1_HDB03 \
  msl_SAPHana_HN1_HDB03

# Clean up the HANA resources. The HANA resources might have failed because of a known issue.
sudo crm resource cleanup rsc_SAPHana_HN1_HDB03

sudo crm configure property priority-fencing-delay=30

sudo crm configure property maintenance-mode=false
sudo crm configure rsc_defaults resource-stickiness=1000
sudo crm configure rsc_defaults migration-threshold=5000
