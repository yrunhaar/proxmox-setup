#!/bin/bash

# Color output functions
red() { echo -e "\033[31m$1\033[0m"; }
green() { echo -e "\033[32m$1\033[0m"; }
blue() { echo -e "\033[34m$1\033[0m"; }
cyan() { echo -e "\033[36m$1\033[0m"; }


# Define paths
PROXMOX_SETUP_DIR="$HOME/proxmox-setup"
PACKER_DIR="$PROXMOX_SETUP_DIR/packer"
TERRAFORM_DIR="$PROXMOX_SETUP_DIR/terraform"

# Function to provide Proxmox VM setup instructions
build_packer() {
    blue "Building Packer image..."
    cd $PACKER_DIR/talos-packer/
    packer init -upgrade .
    packer validate -var-file="vars/local.pkrvars.hcl" .
    packer build -var-file="vars/local.pkrvars.hcl" .
    green "Packer image built successfully!"
}

# Function to build Terraform
build_terraform() {
    blue "Building Terraform configuration..."
    cd $TERRAFORM_DIR/
    # Initialize Terraform
    terraform init
    # Plan
    terraform plan -out .tfplan
    # Apply
    terraform apply .tfplan
    green "Terraform configuration applied successfully!"
}

# Main function
main() {
    build_packer
    build_terraform
}

# Call the main function
main