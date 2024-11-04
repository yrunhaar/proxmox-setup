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
PACKER_VM_ID="9300"
OUTPUT_FILE="/tmp/terraform_output.txt"  # Local file path

# Prompt for VM_ID
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

# Function to export Terraform output and assign sequential IPs
export_terraform_output() {
    # Capture Terraform output in a local file
    terraform -chdir="$TERRAFORM_DIR" output -json > "$OUTPUT_FILE"
    green "Terraform output saved locally at $OUTPUT_FILE."

    # Prompt for starting IP
    read -p "Enter the starting IP address for the first master node (e.g., 192.168.1.100): " START_IP

    # Calculate base IP and starting last octet
    BASE_IP=$(echo "$START_IP" | cut -d '.' -f 1-3)
    LAST_OCTET=$(echo "$START_IP" | cut -d '.' -f 4)

    # Load MAC addresses from the JSON output
    MASTER_MACS=($(jq -r '.master_macaddrs.value[]' "$OUTPUT_FILE"))
    WORKER_MACS=($(jq -r '.worker_macaddrs.value[]' "$OUTPUT_FILE"))

    # Generate IPs for Master VMs
    MASTER_IPS=()
    for i in "${!MASTER_MACS[@]}"; do
        ip="$BASE_IP.$((LAST_OCTET + i))"
        MASTER_IPS+=("\"$ip\"")
    done

    # Generate IPs for Worker VMs
    WORKER_IPS=()
    for i in "${!WORKER_MACS[@]}"; do
        ip="$BASE_IP.$((LAST_OCTET + ${#MASTER_MACS[@]} + i))"
        WORKER_IPS+=("\"$ip\"")
    done

    # Add IPs to the JSON file
    jq --argjson master_ips "$(echo "[${MASTER_IPS[*]}]" | jq .)" \
       --argjson worker_ips "$(echo "[${WORKER_IPS[*]}]" | jq .)" \
       '. + {master_ips: $master_ips, worker_ips: $worker_ips}' "$OUTPUT_FILE" > /tmp/temp_output.json && mv /tmp/temp_output.json "$OUTPUT_FILE"

    green "IP addresses automatically assigned for all Master and Worker VMs."
    green "Terraform output and IP addresses saved locally at $OUTPUT_FILE."

    # Check if VM_ID is provided and VM exists
    if [[ -n "$VM_ID" ]] && check_vm_exists "$VM_ID"; then
        blue "Sending Terraform output to VM with ID $VM_ID..."
        
        # Send file to /tmp/terraform_output.txt on the VM
        qm guest exec "$VM_ID" -- /bin/bash -c "cat > /tmp/terraform_output.txt" < "$OUTPUT_FILE" || { red "Failed to send Terraform output to VM"; return 1; }

        green "Terraform output successfully sent to VM with ID $VM_ID at /tmp/terraform_output.txt."
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