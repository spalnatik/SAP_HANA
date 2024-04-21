#!/bin/bash
# build the rg , AS and 2 VMs for NFS share and one VM for iscsi target

logfile="./hana_cluster_log"
#set -x

rgname="sles-hana-rg"
loc="eastus"
asname="sleshana"
vmname1="hn1-db-0"
vmname2="hn1-db-1"
vmname3="sbd-storage"
lbname="sles-hana-lb"
vnetname="hanavnet"
subnetname="hanasubnet"
sku_size="Standard_E4-2ads_v5"
shared_disk=false
offer="SUSE:sles-sap-15-sp2:gen1:latest"

frontendip="hana-db-fwip"
backendpoolname="hana-db-BP"
probename="hana-db-probe"
sshpubkeyfile="/home/$USER/.ssh/id_rsa.pub"

DiskSizeInGB=4
DiskName="SBD-disk1"
ShareNodes=2
SkuName="Premium_LRS"

if [ -f "./username.txt" ]
then
    username=`cat username.txt`
else
    read -p "Please enter the username: " username
fi

if [ -f "./password.txt" ]
then
    password=`cat password.txt`
else
    read -s -p "Please enter the password: " password
fi

echo " "

echo "Choose the Azure fence agent device:"
echo "1. sp(service principal)"
echo "2. msi(managed identity)"
read -p "Enter the number of your choice: " choice

# Execute the corresponding function based on the user's choice

echo ""

date >> $logfile
echo "Creating RG $rgname.."
az group create --name $rgname --location $loc >> $logfile

echo "Async Creating availability set .."
az vm availability-set create -n $asname -g $rgname --platform-fault-domain-count 3 --platform-update-domain-count 20 --no-wait >> $logfile

echo "Sync Creating VNET .."
az network vnet create --name $vnetname -g $rgname --address-prefixes 10.0.0.0/24 --subnet-name $subnetname --subnet-prefixes 10.0.0.0/24  >> $logfile

echo "Async Creating load balancer .."
az network lb create --resource-group $rgname --name $lbname --location $loc --backend-pool-name $backendpoolname --frontend-ip-name $frontendip --private-ip-address "10.0.0.4" --sku "Standard" --vnet-name $vnetname --subnet $subnetname --no-wait >> $logfile

echo "Async Creating First node, with both ssh key and password authentication methods .."
az vm create -g $rgname -n $vmname1 --admin-username $username --admin-password $password --authentication-type "all"  --ssh-key-values $sshpubkeyfile --availability-set $asname --image $offer  --size "$sku_size" --vnet-name $vnetname --subnet $subnetname --public-ip-sku Standard --private-ip-address "10.0.0.5" --no-wait >> $logfile

echo "Sync Creating Second node, with both ssh key and password authentication methods .."
az vm create -g $rgname -n $vmname2 --admin-username $username --admin-password $password --authentication-type "all" --ssh-key-values $sshpubkeyfile --availability-set $asname --image $offer  --size "$sku_size" --vnet-name $vnetname --subnet $subnetname --public-ip-sku Standard --private-ip-address "10.0.0.6" >> $logfile

echo "Connecting the machines to the load balancer .."
az network lb probe create --lb-name $lbname --resource-group $rgname --name $probename --port 62503 --protocol Tcp >> $logfile

nic1name1=`az vm show -g $rgname -n $vmname1  --query networkProfile.networkInterfaces[].id -o tsv | cut -d / -f 9`
az network nic ip-config address-pool add --address-pool $backendpoolname --ip-config-name ipconfig$vmname1 --nic-name $nic1name1 --resource-group $rgname --lb-name $lbname  >> $logfile

nic1name2=`az vm show -g $rgname -n $vmname2  --query networkProfile.networkInterfaces[].id -o tsv | cut -d / -f 9`
az network nic ip-config address-pool add --address-pool $backendpoolname --ip-config-name ipconfig$vmname2 --nic-name $nic1name2 --resource-group $rgname --lb-name $lbname  >> $logfile

echo "Creating load balancing rule .."
az network lb rule create --resource-group $rgname --lb-name $lbname --name "Hana-DB-rule" --backend-port 0 --frontend-port 0 \
 --frontend-ip-name $frontendip --backend-pool-name $backendpoolname --protocol All --floating-ip true \
 --idle-timeout 30 --probe-name $probename  >> $logfile

	
echo 'As we are using this machine to deploy and we can authenticate without password, we will update the authenctication between the 2 cluster nodes ..'
echo 'Generating and getting RSA public key of root user on first node ..'
vm_1_pip=`az vm list-ip-addresses -g $rgname -n $vmname1 --query [0].virtualMachine.network.publicIpAddresses[0].ipAddress -o tsv`
vm_2_pip=`az vm list-ip-addresses -g $rgname -n $vmname2 --query [0].virtualMachine.network.publicIpAddresses[0].ipAddress -o tsv`

# getting VM 1 public key
ssh -o "StrictHostKeyChecking=no" $username@$vm_1_pip 'sudo cat /dev/zero | sudo ssh-keygen -t rsa -q -N ""' >> $logfile
vm_1_public_key=`ssh -o "StrictHostKeyChecking=no" $username@$vm_1_pip 'sudo cat /root/.ssh/id_rsa.pub'`

#getting VM 2 public key
ssh -o "StrictHostKeyChecking=no" $username@$vm_2_pip 'sudo cat /dev/zero | sudo ssh-keygen -t rsa -q -N ""' >> $logfile
vm_2_public_key=`ssh -o "StrictHostKeyChecking=no" $username@$vm_2_pip 'sudo cat /root/.ssh/id_rsa.pub'`

echo 'Done getting the ssh keys, updating both nodes to have passwordless root access between them'
az vm run-command invoke -g $rgname -n $vmname1 --command-id RunShellScript --scripts "echo $vm_2_public_key > /root/.ssh/authorized_keys" >> $logfile
az vm run-command invoke -g $rgname -n $vmname2 --command-id RunShellScript --scripts "echo $vm_1_public_key > /root/.ssh/authorized_keys" >> $logfile

num_disks=4

for ((i=1; i<=num_disks; i++)); do
    disk_name="$vmname1$i"
    size_gb=4

    az vm disk attach \
        -g "$rgname" \
        --vm-name "$vmname1" \
        --name "$disk_name" \
        --new \
        --size-gb "$size_gb"

    if [ $? -eq 0 ]; then
        echo "Disk $disk_name successfully attached to $vmname1."
    else
        echo "Failed to attach disk $disk_name."
    fi
done

num_disks=4

for ((i=1; i<=num_disks; i++)); do
    disk_name="$vmname2$i"
    size_gb=4

    az vm disk attach \
        -g "$rgname" \
        --vm-name "$vmname2" \
        --name "$disk_name" \
        --new \
        --size-gb "$size_gb"

    if [ $? -eq 0 ]; then
        echo "Disk $disk_name successfully attached to $vmname2."
    else
        echo "Failed to attach disk $disk_name."
    fi
done



echo 'Entering the final phase of configuring the cluster, we will start with node 2 then node 1'
az vm extension set \
--resource-group $rgname \
--vm-name $vmname2 \
--name customScript \
--publisher Microsoft.Azure.Extensions \
--protected-settings '{"fileUris": ["https://raw.githubusercontent.com/spalnatik/SAP_HANA/main/cluster_setup.sh"],"commandToExecute": "./cluster_setup.sh"}' >> $logfile

az vm extension set \
--resource-group $rgname \
--vm-name $vmname1 \
--name customScript \
--publisher Microsoft.Azure.Extensions \
--protected-settings '{"fileUris": ["https://raw.githubusercontent.com/spalnatik/SAP_HANA/main/cluster_setup.sh"],"commandToExecute": "./cluster_setup.sh"}' >> $logfile

echo " configuring fencing device " 

if [ "$choice" = "1" ]; then

    appregname=myclusterspautosuse
    subscriptionID=$(az group show --name "sles-hana-rg" --query "id" --output tsv | cut -d '/' -f 3) >> $logfile
    app_exists=$(az ad app list --display-name "$appregname" --query "[0].appId" --output tsv)

    if [ -z "$app_exists" ]; then
        echo "Azure AD App with the name '$appregname' doesn't exist."
    else
    # The App exists, so delete it
        echo "Azure AD App with the name '$appregname' already exists. Deleting the existing App..."
        keys=$(az ad app credential list --id $app_exists --query "[].keyId" --output tsv)
        for key in $keys; do az ad app credential delete --id $app_exists --key-id $key; done
        az ad app delete --id "$app_exists"
        echo "Deleted existing Azure AD App with App ID: $app_exists"
        sleep 60
    fi

    clientid=$(az ad app create --display-name $appregname --query appId --output tsv)
    #echo $clientid
    az ad sp create --id $clientid
    objectid=$(az ad app show --id $clientid --query objectId --output tsv)
    ###Add client secret with expiration. The default is one year.
    clientsecretname=mycert2
    clientsecretduration=1
    clientsecret=$(az ad app credential reset --id $clientid --append --display-name $clientsecretname --years $clientsecretduration --query password --output tsv)

    az role assignment create --assignee $clientid --role "Virtual Machine Contributor" --resource-group $rgname
    echo "creating fencing devices"

    export rgname
    export subscriptionID
    #export password

    wget -O susespn.sh https://raw.githubusercontent.com/spalnatik/SAP_HANA/main/susespn.sh
    filename='susespn.sh'

    az vm run-command invoke -g $rgname -n $vmname1 --command-id RunShellScript --scripts @$filename --parameters $clientid $clientsecret $rgname $subscriptionID >>  $logfile

else

    subscriptionID=$(az group show --name "sles-hana-rg" --query "id" --output tsv | cut -d '/' -f 3) >> $logfile

    echo "add role assignment to node1"

    spID=$(az resource list  --resource-group "sles-hana-rg" -n "hn1-db-0" --query [*].identity.principalId --out tsv) >> $logfile

    az role assignment create --assignee $spID --role 'Virtual Machine Contributor' --scope /subscriptions/$subscriptionID/resourceGroups/$rgname/providers/Microsoft.Compute/virtualMachines/hn1-db-0 >> $logfile

    az role assignment create --assignee $spID --role 'Virtual Machine Contributor' --scope /subscriptions/$subscriptionID/resourceGroups/$rgname/providers/Microsoft.Compute/virtualMachines/hn1-db-1 >> $logfile

    echo "role assignment to node2"

    spID1=$(az resource list  --resource-group "sles-hana-rg" -n "hn1-db-1" --query [*].identity.principalId --out tsv) >> $logfile

    az role assignment create --assignee $spID1 --role 'Virtual Machine Contributor' --scope /subscriptions/$subscriptionID/resourceGroups/$rgname/providers/Microsoft.Compute/virtualMachines/hn1-db-0 >> $logfile

    az role assignment create --assignee $spID1 --role 'Virtual Machine Contributor' --scope /subscriptions/$subscriptionID/resourceGroups/$rgname/providers/Microsoft.Compute/virtualMachines/hn1-db-1 >> $logfile

    #sleep 120

    echo "creating fencing devices"

    export rgname
    export subscriptionID
    #export password
    wget -O susemi.sh https://raw.githubusercontent.com/spalnatik/SAP_HANA/main/susemi.sh
    filename='susemi.sh'
    az vm run-command invoke -g $rgname -n $vmname1 --command-id RunShellScript --scripts @$filename --parameters $rgname $subscriptionID >>  $logfile
fi

echo "formatting data disks"

az vm extension set \
    --resource-group $rgname \
    --vm-name $vmname1 \
    --name customScript \
    --publisher Microsoft.Azure.Extensions \
    --protected-settings "{\"fileUris\": [\"https://raw.githubusercontent.com/spalnatik/SAP_HANA/main/format.sh\"],\"commandToExecute\": \"./format.sh \"}" >> $logfile

az vm extension set \
    --resource-group $rgname \
    --vm-name $vmname2 \
    --name customScript \
    --publisher Microsoft.Azure.Extensions \
    --protected-settings "{\"fileUris\": [\"https://raw.githubusercontent.com/spalnatik/SAP_HANA/main/format.sh\"],\"commandToExecute\": \"./format.sh \"}" >> $logfile

echo "HANA installation from node2 to node1"

az vm extension set \
--resource-group $rgname \
--vm-name $vmname2 \
--name customScript \
--publisher Microsoft.Azure.Extensions \
--protected-settings '{"fileUris": ["https://raw.githubusercontent.com/spalnatik/SAP_HANA/main/HAinstall.sh"],"commandToExecute": "./HAinstall.sh"}' >> $logfile

az vm extension set \
--resource-group $rgname \
--vm-name $vmname1 \
--name customScript \
--publisher Microsoft.Azure.Extensions \
--protected-settings '{"fileUris": ["https://raw.githubusercontent.com/spalnatik/SAP_HANA/main/HAinstall.sh"],"commandToExecute": "./HAinstall.sh"}' >> $logfile


echo " HA configure"

az vm extension set \
--resource-group $rgname \
--vm-name $vmname1 \
--name customScript \
--publisher Microsoft.Azure.Extensions \
--protected-settings '{"fileUris": ["https://raw.githubusercontent.com/spalnatik/SAP_HANA/main/hanaconfigure.sh"],"commandToExecute": "./hanaconfigure.sh"}' >> $logfile


