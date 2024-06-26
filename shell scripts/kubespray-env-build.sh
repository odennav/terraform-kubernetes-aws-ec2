#!/bin/bash

KUBESPRAYPATH="/terraform-kubernetes-aws-ec2/bash-scripts"        
IPADDR_LIST_FILE="$KUBESPRAYPATH/ipaddr-list.txt"  
INV_PARENT_DIR=/kubespray


venvActvt() {                                                  #Create virtual environment and activate it.
    VENVDIR=kubespray-venv
    
    python3 -m venv ../$VENVDIR

    if [ -d "$VENVDIR" ] || [ -d "$KUBESPRAYPATH" ]; then
        source ../$VENVDIR/bin/activate
    else
        echo "Error: Both Kubespray-venv & terraform-kubernetes-aws-ec2 directories not found." >&2
        exit 1
    fi
}


pubKyAuth() {        
    ssh-keygen -t rsa -b 4096                                   #Create ssh-key pair. Press enter for all prompts on location until keys are created.
    
    ls -la /root/.ssh/                                          #Confirm private and public keys are created.

    while read -r name ip; do                                   #Iterate through ipaddr-list file and use ssh-copy-id.
        ip=$(echo "$ip" | tr -d '\r')
        ssh-copy-id "root@$ip"                                  #Use ssh-copy-id utility to copy public keys to remote servers.
    
    done < "$IPADDR_LIST_FILE"                                  #While loop reads from ipaddr_list_file.
}




ansblInv() {
    
    if [ "$(pwd)" != "$KUBESPRAYPATH" ]; then
        echo "Error: Current directory is not $KUBESPRAYPATH." >&2
        exit 1
    fi

    REQUIREMENTS="$KUBESPRAYPATH/requirements.txt"

    if [ -e "$REQUIREMENTS" ]; then
        pip3 install -U -r "$REQUIREMENTS"                                #Install Ansible and other requirements to deploy kubespray
        echo "Dependencies in requirements file installed"
    fi

    cp -rfp $INV_PARENT_DIR/inventory/sample $INV_PARENT_DIR/inventory/mycluster                   #Copy `inventory/sample` as `inventory/mycluster`

    #Update Ansible inventory file with inventory builder
    declare -a IPS=()

    while read -r name ip_address; do                                     #Read the file and add IP addresses to the array
        ip_addr=$(echo "$ip_address" | tr -d '\r')
        IPS+=("$ip_addr")
    done < "$IPADDR_LIST_FILE"

    printf 'IP addresses in IPS array: %s\n' "${IPS[@]}"                  #Print the IPS array for verification

    CONFIG_FILE=$INV_PARENT_DIR/inventory/mycluster/hosts.yaml python3 $INV_PARENT_DIR/contrib/inventory_builder/inventory.py "${IPS[@]}"
}

hstInvEdt() {
#Input and output file paths
INPUT_FILE="/kubespray/inventory/mycluster/hosts.yaml"
INPUT_NULL_FILE="/kubespray/inventory/mycluster/hosts-null.yaml"
OUTPUT_FILE="/kubespray/inventory/mycluster/hosts.yaml"
TEMP_JSON_FILE="/kubespray/inventory/mycluster/temp.json"

mv $INPUT_FILE $INPUT_NULL_FILE

# Ensure yq are installed
command -v yq > /dev/null || { echo "Error: yq not found. Please install yq (https://github.com/mikefarah/yq)" >&2; exit 1; }

touch temp.yaml

tr -d '\r' < "$INPUT_NULL_FILE" > "temp.yaml"    #Remove carriage returns from the input file

yq -r 'del(
  .all.children.kube_node.hosts.node1,
  .all.children.kube_node.hosts.node2,
  .all.children.etcd.hosts.node3
)' "temp.yaml" > "$TEMP_JSON_FILE"    #Convert to json and filter out unwanted nodes

cat $TEMP_JSON_FILE | yq -y > "$OUTPUT_FILE"   #Convert JSON to YAML using jq

sed -i.bak 's/ null$//g' "$OUTPUT_FILE"

rm "temp.yaml" "$TEMP_JSON_FILE" "$INPUT_NULL_FILE"    #Clean up temporary files

echo "Transformation completed. Check $OUTPUT_FILE."
}


instlKub() {
    sudo snap install kubectl --classic                                  #Install kubectl, a command-line client for controlling Kubernetes clusters.
    kubectl version                                                      #Confirm kubectl is installed
}



#MAIN SCRIPT

if [ "$(pwd)" = "$KUBESPRAYPATH" ]; then                                  #Check if the current directory is /terraform-k8s-aws_ec2/bash-scripts.
    
venvActvt
pubKyAuth
ansblInv
hstInvEdt
instlKub
    
else echo "Error: Current directory is not $KUBESPRAYPATH." >&2
    exit 1
fi
