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

# Function to prompt for template and image details
prompt_template_and_image_details() {
  blue "Please provide the following Proxmox templates and images details:"

  read -p "Enter PfSense ISO Template ID (default: netgate-installer-amd64.iso): " PFSENSE_ISO_TEMPLATE
  PFSENSE_ISO_TEMPLATE=${PFSENSE_ISO_TEMPLATE:-"netgate-installer-amd64.iso"}
  read -p "Enter Fedora ISO Template ID (default: Fedora-Workstation-Live-x86_64-40-1.14.iso): " FEDORA_ISO_TEMPLATE
  FEDORA_ISO_TEMPLATE=${FEDORA_ISO_TEMPLATE:-"Fedora-Workstation-Live-x86_64-40-1.14.iso"}
  read -p "Enter Ubuntu Server ISO Template ID (default: ubuntu-24.04.1-live-server-amd64.iso): " UBUNTU_SERVER_ISO_TEMPLATE
  UBUNTU_SERVER_ISO_TEMPLATE=${UBUNTU_SERVER_ISO_TEMPLATE:-"ubuntu-24.04.1-live-server-amd64.iso"}

  read -p "Enter Packer Base ISO File (default: archlinux-2024.10.01-x86_64.iso): " BASE_ISO_FILE
  BASE_ISO_FILE=${BASE_ISO_FILE:-"archlinux-2024.10.01-x86_64.iso"}
  read -p "Enter Talos Disk Image schematic ID (default: ce4c980550dd2ab1b17bbf2b08801c7eb59418eafe8f279833297925d67c7515): " TALOS_DISK_IMAGE_ID
  TALOS_DISK_IMAGE_ID=${TALOS_DISK_IMAGE_ID:-"ce4c980550dd2ab1b17bbf2b08801c7eb59418eafe8f279833297925d67c7515"}
  read -p "Enter Talos Disk Image version number (default: v1.8.2): " TALOS_VERSION
  TALOS_VERSION=${TALOS_VERSION:-"v1.8.2"}

  read -p "Enter Mattermost CT Template ID (default: debian-12-turnkey-mattermost_18.0-1_amd64.tar.gz): " MATTERMOST_CT_TEMPLATE
  MATTERMOST_CT_TEMPLATE=${MATTERMOST_CT_TEMPLATE:-"debian-12-turnkey-mattermost_18.0-1_amd64.tar.gz"}
  read -p "Enter PostgreSQL CT Template ID (default :debian-12-turnkey-postgresql_18.1-1_amd64.tar.gz ): " POSTGRESQL_CT_TEMPLATE
  POSTGRESQL_CT_TEMPLATE=${POSTGRESQL_CT_TEMPLATE:-"debian-12-turnkey-postgresql_18.1-1_amd64.tar.gz"}
}

# Function to create packer configuration file
create_packer_configuration() {
  mkdir -p $PACKER_DIR/talos-packer/vars
  blue "Creating Packer local.pkrvars.hcl configuration..."

  cat > $PACKER_DIR/talos-packer/vars/local.pkrvars.hcl <<EOL
proxmox_api_url       = "https://$PROXMOX_SERVER_IP:8006/api2/json"
proxmox_node          = "$PROXMOX_NODE"
proxmox_api_token_id  = "$PROXMOX_TOKEN_ID"
proxmox_api_token_secret = "$PROXMOX_TOKEN_SECRET"
proxmox_storage       = "$STORAGE_POOL"
cpu_type              = "host"
base_iso_file         = "local:iso/$BASE_ISO_FILE"
talos_version         = "$TALOS_VERSION"
talos_disk_image_id      = "$TALOS_DISK_IMAGE_ID"
EOL
  green "Packer local.pkrvars.hcl created."
}

# Function to create Terraform credentials file
create_terraform_credentials() {
  blue "Creating Terraform credentials.auto.tfvars..."

  cat > $TERRAFORM_DIR/credentials.auto.tfvars <<EOL
proxmox_api_url          = "https://$PROXMOX_SERVER_IP:8006/api2/json"
proxmox_api_token_id     = "$PROXMOX_TOKEN_ID"
proxmox_api_token_secret = "$PROXMOX_TOKEN_SECRET"
target_node              = "$PROXMOX_NODE"
storage_pool             = "$STORAGE_POOL"
talos_version            = "$TALOS_VERSION"
talos_disk_image_id      = "$TALOS_DISK_IMAGE_ID"
EOL
  green "Terraform credentials.auto.tfvars created."
}

# Function to create images.tfvars for specifying templates
create_images_tfvars() {
  blue "Creating Terraform images.tfvars..."

  cat > $TERRAFORM_DIR/images.tfvars <<EOL
mattermost_ct_template   = "$MATTERMOST_CT_TEMPLATE"
postgresql_ct_template   = "$POSTGRESQL_CT_TEMPLATE"
pfsense_iso_template     = "$PFSENSE_ISO_TEMPLATE"
fedora_iso_template      = "$FEDORA_ISO_TEMPLATE"
ubuntu_server_iso_template = "$UBUNTU_SERVER_ISO_TEMPLATE"
EOL
  green "Terraform images.tfvars created."
}

# Main function
main() {
  setup_proxmox_user_instructions
  prompt_proxmox_details
  generate_ssh_key
  prompt_template_and_image_details
  create_packer_configuration
  create_terraform_credentials
  create_images_tfvars
}

# Call the main function
main