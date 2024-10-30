#!/bin/bash

# Color output functions
red() { echo -e "\033[31m$1\033[0m"; }
green() { echo -e "\033[32m$1\033[0m"; }
blue() { echo -e "\033[34m$1\033[0m"; }
cyan() { echo -e "\033[36m$1\033[0m"; }

# Function to provide Proxmox user setup instructions
setup_proxmox_user_instructions() {
  cyan "=================================================="
  cyan "Setting up the necessary user and API token for Terraform in Proxmox"
  cyan "Follow these steps carefully to ensure Terraform can access Proxmox via API:"
  cyan ""
  cyan "1. Create a new user in Proxmox for Terraform"
  cyan "   Go to: Datacenter > Permissions > Users > Add"
  cyan "   Set the following values:"
  cyan "     - User name: terraform-user"
  cyan "     - Realm: pam (Linux PAM standard authentication)"
  cyan "     - Expire: never"
  cyan "     - Enabled: Yes"
  cyan "   Then click 'Add' to create the user."
  cyan ""
  cyan "2. Assign permissions to 'terraform-user'"
  cyan "   Go to: Datacenter > Permissions > Add"
  cyan "   Set the following values:"
  cyan "     - Path: '/' (This grants permissions at the root level)"
  cyan "     - User: terraform-user@pam"
  cyan "     - Role: PVEVMAdmin"
  cyan "   Then click 'Add' to save."
  cyan ""
  cyan "3. Generate an API token for 'terraform-user'"
  cyan "   Go to: Datacenter > Permissions > API Tokens > Add"
  cyan "   Set the following values:"
  cyan "     - User: terraform-user@pam"
  cyan "     - Token ID: terraform-token"
  cyan "     - Privilege Separation: Uncheck"
  cyan "     - Expire: never"
  cyan "   After clicking 'Add', save the generated token. This token will only be visible once, so be sure to copy it!"
  cyan "=================================================="
  cyan ""
}

# Function to prompt for Proxmox details
prompt_proxmox_details() {
  read -p "Enter Proxmox Server IP: " PROXMOX_SERVER_IP
  read -p "Enter Proxmox Token ID (default: terraform-user@pam!terraform-token): " PROXMOX_TOKEN_ID
  PROXMOX_TOKEN_ID=${PROXMOX_TOKEN_ID:-"terraform-user@pam!terraform-token"}
  read -p "Enter Proxmox Token Secret: " PROXMOX_TOKEN_SECRET
  read -p "Enter Proxmox Node (default: pve-01): " PROXMOX_NODE
  PROXMOX_NODE=${PROXMOX_NODE:-"pve-01"}
  read -p "Enter the Proxmox Storage Pool (default: local): " STORAGE_POOL
  STORAGE_POOL=${STORAGE_POOL:-"local"}

  export TF_VAR_proxmox_token_id="$PROXMOX_TOKEN_ID"
  export TF_VAR_proxmox_token_secret="$PROXMOX_TOKEN_SECRET"
}

# Function to check or generate SSH key
generate_ssh_key() {
  if [[ ! -f ~/.ssh/id_rsa ]]; then
    blue "Generating SSH key..."
    ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa -N ""
    green "SSH key generated at ~/.ssh/id_rsa"
  else
    green "SSH key already exists at ~/.ssh/id_rsa"
  fi
}

# Function to create Terraform configuration directory and vars.tf
create_terraform_configuration() {
  blue "Creating Terraform configuration under ./terraform/ directory..."
  mkdir -p terraform
  cd terraform

  cat > vars.tf <<EOL
variable "pve_server_ip" {
  description = "Server IP for PVE cluster"
  type        = string
  default     = "$PROXMOX_SERVER_IP"
}

variable "target_node" {
  description = "Proxmox VE node to target"
  type        = string
  default     = "$PROXMOX_NODE"
}

variable "storage_pool" {
  description = "Storage pool in Proxmox VE for container storage"
  type        = string
  default     = "$STORAGE_POOL"
}

variable "lxc_containers" {
  type = map(object({
    vm_id    = number,
    template = string
  }))
}
EOL
}

# Function to initialize Terraform
initialize_terraform() {
  blue "Initializing Terraform configuration..."
  terraform init
  green "Terraform setup is complete! Details have been saved in the ./terraform/ directory."
  green "Run 'terraform apply' to create your LXC containers based on the configuration."
}

# Main script execution
setup_proxmox_user_instructions
prompt_proxmox_details
generate_ssh_key
create_terraform_configuration
initialize_terraform