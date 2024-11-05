#!/bin/bash

# Color output functions
red() { echo -e "\033[31m$1\033[0m"; }
green() { echo -e "\033[32m$1\033[0m"; }
blue() { echo -e "\033[34m$1\033[0m"; }
cyan() { echo -e "\033[36m$1\033[0m"; }

# Define paths
PROXMOX_SETUP_DIR="$HOME/proxmox-setup"
PACKER_DIR="$PROXMOX_SETUP_DIR/packer/talos-packer"
PACKER_VAR_FILE="$PACKER_DIR/vars/local.pkrvars.hcl"
TERRAFORM_DIR="$PROXMOX_SETUP_DIR/terraform"
TF_PLAN_FILE="$TERRAFORM_DIR/.tfplan"
OUTPUT_FILE="$PROXMOX_SETUP_DIR/terraform_output.txt"

PACKER_VM_ID="9300"

# Prompt for VM_ID
read -p "Enter Proxmox Node (default: pve-01): " PROXMOX_NODE
PROXMOX_NODE=${PROXMOX_NODE:-"pve-01"}
read -p "Enter the VM ID to send Terraform output (leave blank to save locally only): " VM_ID

# Function to check if VM exists
check_vm_exists() {
    local vm_id=$1
    if qm list | grep -q " $vm_id "; then
        return 0
    else
        red "VM with ID $vm_id does not exist."
        return 1
    fi
}

# Function to build Packer image
build_packer() {
    if check_vm_exists "$PACKER_VM_ID"; then
        green "VM with ID $PACKER_VM_ID already exists. Skipping Packer build."
        return 0
    fi

    blue "Building Packer image..."

    # Run Packer commands
    packer init -upgrade "$PACKER_DIR" || { red "Packer initialization failed"; exit 1; }
    packer validate -var-file="$PACKER_VAR_FILE" "$PACKER_DIR" || { red "Packer validation failed"; exit 1; }
    packer build -var-file="$PACKER_VAR_FILE" "$PACKER_DIR" || { red "Packer build failed"; exit 1; }

    green "Packer image built successfully!"
}

# Function to build Terraform configuration
build_terraform() {
    blue "Building Terraform configuration..."
    
    terraform -chdir="$TERRAFORM_DIR" init || { red "Terraform initialization failed"; exit 1; }
    terraform -chdir="$TERRAFORM_DIR" plan -var-file="credentials.auto.tfvars" -var-file="images.tfvars" -out="$TF_PLAN_FILE" || { red "Terraform plan failed"; exit 1; }
    terraform -chdir="$TERRAFORM_DIR" apply "$TF_PLAN_FILE" || { red "Terraform apply failed"; exit 1; }
    
    green "Terraform configuration applied successfully!"
}

# Prompt user for IP addresses
prompt_for_ip_addresses() {
    local master_count=${#MASTER_VMIDS[@]}
    local worker_count=${#WORKER_VMIDS[@]}
    MASTER_IPS=()
    WORKER_IPS=()

    blue "Please enter the IP addresses for each master and worker VM by checking DHCP Leases in pfSense GUI."

    for ((i=0; i<master_count; i++)); do
        read -p "Enter IP address for Master VM ID ${MASTER_VMIDS[$i]} (MAC: ${MASTER_MACS[$i]}): " master_ip
        MASTER_IPS+=("$master_ip")
    done

    for ((i=0; i<worker_count; i++)); do
        read -p "Enter IP address for Worker VM ID ${WORKER_VMIDS[$i]} (MAC: ${WORKER_MACS[$i]}): " worker_ip
        WORKER_IPS+=("$worker_ip")
    done

    green "IP addresses collected for all Master and Worker VMs."
}

# Prompt user for IP addresses
prompt_for_ip_addresses() {
    local master_count=${#MASTER_VMIDS[@]}
    local worker_count=${#WORKER_VMIDS[@]}
    MASTER_IPS=()
    WORKER_IPS=()

    # Prompt for the starting subnet
    read -p "Enter the IP subnet (Default: 192.168.1): " BASE_SUBNET
    BASE_SUBNET=${BASE_SUBNET:-"192.168.1"}

    blue "Please enter the last octet of the IP address for each Master and Worker VM based on the subnet $BASE_SUBNET."

    for ((i=0; i<master_count; i++)); do
        read -p "Enter last octet for Master VM ID ${MASTER_VMIDS[$i]} (MAC: ${MASTER_MACS[$i]}): " last_octet
        MASTER_IPS+=("$BASE_SUBNET.$last_octet")
    done

    for ((i=0; i<worker_count; i++)); do
        read -p "Enter last octet for Worker VM ID ${WORKER_VMIDS[$i]} (MAC: ${WORKER_MACS[$i]}): " last_octet
        WORKER_IPS+=("$BASE_SUBNET.$last_octet")
    done

    green "IP addresses collected for all Master and Worker VMs."
}

# Function to export Terraform output and assign specified IPs
export_terraform_output() {
    # Capture Terraform output in a local file
    terraform -chdir="$TERRAFORM_DIR" output -json > "$OUTPUT_FILE"
    green "Terraform output saved locally at $OUTPUT_FILE."

    # Load MAC addresses from the JSON output
    MASTER_MACS=($(jq -r '.master_macaddrs.value[]' "$OUTPUT_FILE"))
    WORKER_MACS=($(jq -r '.worker_macaddrs.value[]' "$OUTPUT_FILE"))

    # Collect IP addresses from user
    prompt_for_ip_addresses

    # Add IP addresses to JSON file in correct format
    jq --argjson master_ips "$(printf '%s\n' "${MASTER_IPS[@]}" | jq -R . | jq -s .)" \
       --argjson worker_ips "$(printf '%s\n' "${WORKER_IPS[@]}" | jq -R . | jq -s .)" \
       '. + {master_ips: $master_ips, worker_ips: $worker_ips}' "$OUTPUT_FILE" > /tmp/temp_output.json && mv /tmp/temp_output.json "$OUTPUT_FILE"

    green "IP addresses saved in Terraform output file."

    # Verify the content of the file before attempting to send it to VM
    if [[ -s "$OUTPUT_FILE" ]]; then
        green "Output file verified with IP addresses."
    else
        red "Output file is empty. Check the process for errors."
        exit 1
    fi

    # Check if VM_ID is provided and VM exists
    if [[ -n "$VM_ID" ]] && check_vm_exists "$VM_ID"; then
        blue "Sending Terraform output and setup scripts to VM with ID $VM_ID..."

        # Ensure the directories exist on the VM
        qm guest exec "$VM_ID" -- mkdir -p /tmp/proxmox-setup/scripts || { red "Failed to create directories on VM"; return 1; }

        # Function to transfer a file in one go
        function transfer_file() {
            local src_file=$1
            local dest_file=$2
            
            pvesh create /nodes/$PROXMOX_NODE/qemu/$VM_ID/agent/file-write --content "$(cat $src_file)" --file "$dest_file" || { red "Failed to send $src_file to VM"; return 1; }
        }

        # Transfer terraform_output.txt
        transfer_file "$OUTPUT_FILE" "/tmp/proxmox-setup/terraform_output.txt"

        # Transfer setup-talos.sh
        transfer_file "$PROXMOX_SETUP_DIR/scripts/talos/setup-talos.sh" "/tmp/proxmox-setup/scripts/setup-talos.sh"

        # Transfer install-tools.sh
        transfer_file "$PROXMOX_SETUP_DIR/scripts/setup/install-tools.sh" "/tmp/proxmox-setup/scripts/install-tools.sh"

        green "Terraform output and setup scripts successfully sent to VM with ID $VM_ID."
    else
        green "No VM ID provided or VM does not exist. Output saved locally only."
    fi
}

# Main function
main() {
    build_packer
    build_terraform
    export_terraform_output
}

# Call the main function
main