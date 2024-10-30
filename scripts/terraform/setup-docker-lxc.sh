#!/bin/bash

# Color output functions
red() { echo -e "\033[31m$1\033[0m"; }
green() { echo -e "\033[32m$1\033[0m"; }
blue() { echo -e "\033[34m$1\033[0m"; }
cyan() { echo -e "\033[36m$1\033[0m"; }

# Function to get the next available 9xx ID
get_next_id() {
    for id in {900..999}; do
        if ! pct status $id &>/dev/null; then
            echo $id
            return
        fi
    done
    red "No available ID found in the range 900-999."
    exit 1
}

# Function to select VM size
select_vm_size() {
    blue "Select VM size for the GitLab Runner:"
    cyan "1) Small (2 cores, 2048MB memory, 16GB disk)"
    cyan "2) Medium (4 cores, 4096MB memory, 32GB disk)"
    cyan "3) Large (8 cores, 8192MB memory, 64GB disk)"
    read -p "Select size (default: 1): " SIZE_OPTION

    case "$SIZE_OPTION" in
        2) TEMPLATE_NAME="ubuntu-2204-medium" ;;
        3) TEMPLATE_NAME="ubuntu-2204-large" ;;
        *) TEMPLATE_NAME="ubuntu-2204-small" ;;
    esac

    green "Selected VM size: $TEMPLATE_NAME"
}

# Function to register GitLab Runner on the VM using authentication token
register_gitlab_runner_vm() {
    blue "Registering GitLab Runner on VM $VM_ID at $VM_IP..."

    cyan "Instructions to create a GitLab Runner authentication token:"
    cyan "1. Navigate to your GitLab project."
    cyan "2. Go to 'Settings' > 'CI/CD'."
    cyan "3. Expand the 'Runners' section."
    cyan "4. Click 'New project runner' and set up a runner with the following settings:"
    cyan "   - Tags: self-hosted"
    cyan "   - Runner Description: 'Runner for $PROJECT_NAME'"
    cyan "   - Protected: True"
    cyan "   - Lock to current projects: True"
    cyan "5. Copy the 'Runner Authentication Token' (starts with glrt-). You will use this token in the next step."

    read -p "Enter your GitLab project authentication token for $PROJECT_NAME: " gitlab_runner_token

    ssh "$VM_USER@$VM_IP" <<EOF
        sudo gitlab-runner register \
        --non-interactive \
        --url https://gitlab.com/ \
        --token "$gitlab_runner_token" \
        --description 'Runner for $PROJECT_NAME' \
        --executor docker \
        --docker-image "docker:24.0.5" \
        --docker-privileged
EOF
    if [ $? -ne 0 ]; then
        red "Error registering GitLab Runner on VM $VM_ID."
        exit 1
    fi
    green "GitLab Runner registered on VM $VM_ID."
}

# Main script logic
read -p "Enter the GitLab project URL (e.g., https://gitlab.com/<groupname>/<projectname>): " GITLAB_URL
PROJECT_NAME=$(basename "$gitlab_repo_url")
VM_ID=$(get_next_id)


blue "Creating VM with ID $VM_ID for GitLab Project: $PROJECT_NAME"

# Select VM size
select_vm_size

# Set up VM parameters
read -p "Enter VM IP address: " VM_IP
VM_USER="terraform-user"

# Check if nodes variable exists in vars.tf, if not, initialize it
if ! grep -q "variable \"nodes\"" vars.tf; then
  echo 'variable "nodes" {' >> vars.tf
  echo '  type = map(object({' >> vars.tf
  echo '    vm_id    = optional(number, 0),' >> vars.tf
  echo '    template = string' >> vars.tf
  echo '  }))' >> vars.tf
  echo '  default = {}' >> vars.tf
  echo '}' >> vars.tf
fi

# Backup vars.tf before modification
cp vars.tf vars.tf.bak

# Append VM details to `nodes` map without specifying cores, memory, or disk
sed -i '/default = {/a \
    "'"$PROJECT_NAME"'" = { \
      vm_id    = '"$VM_ID"', \
      template = "'"$TEMPLATE_NAME"'" \
    },
' vars.tf

green "VM configuration for $PROJECT_NAME added to vars.tf."

# Initialize and apply Terraform
blue "Initializing and applying the Terraform configuration to create the VM..."

terraform init
terraform apply -auto-approve

# Register GitLab Runner on the new VM
register_gitlab_runner_vm
green "Setup for GitLab Runner VM complete. VM ID: $VM_ID, IP: $VM_IP, Project: $PROJECT_NAME"