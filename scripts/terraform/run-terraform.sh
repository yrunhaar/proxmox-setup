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

# Function to check if VM exists
check_vm_exists() {
    local vm_id=$1
    if qm list | grep -q " $vm_id "; then
        green "VM with ID $vm_id already exists. Skipping Packer build."
        return 0
    else
        return 1
    fi
}

# Function to build Packer image
build_packer() {
    local vm_id=9300  # Replace with your target VM ID

    # Check if VM already exists
    if check_vm_exists "$vm_id"; then
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
    terraform -chdir="$TERRAFORM_DIR" plan -out="$TF_PLAN_FILE" || { red "Terraform plan failed"; exit 1; }
    terraform -chdir="$TERRAFORM_DIR" apply "$TF_PLAN_FILE" || { red "Terraform apply failed"; exit 1; }
    
    green "Terraform configuration applied successfully!"
}

# Main function
main() {
    build_packer
    build_terraform
}

# Call the main function
main