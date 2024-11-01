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

# Function to build Packer image
build_packer() {
    blue "Building Packer image..."
    cd "$PACKER_DIR/talos-packer" || { red "Failed to navigate to $PACKER_DIR/talos-packer"; exit 1; }
    packer init -upgrade . || { red "Packer initialization failed"; exit 1; }
    packer validate -var-file="vars/local.pkrvars.hcl" . || { red "Packer validation failed"; exit 1; }
    packer build -var-file="vars/local.pkrvars.hcl" . || { red "Packer build failed"; exit 1; }
    green "Packer image built successfully!"
}

# Function to build Terraform configuration
build_terraform() {
    blue "Building Terraform configuration..."
    cd "$TERRAFORM_DIR" || { red "Failed to navigate to $TERRAFORM_DIR"; exit 1; }
    terraform init || { red "Terraform initialization failed"; exit 1; }
    terraform plan -out .tfplan || { red "Terraform plan failed"; exit 1; }
    terraform apply .tfplan || { red "Terraform apply failed"; exit 1; }
    green "Terraform configuration applied successfully!"
}

# Main function
main() {
    build_packer
    build_terraform
}

# Call the main function
main