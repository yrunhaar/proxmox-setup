#!/bin/bash

# Color output functions for better readability
red() { echo -e "\033[31m$1\033[0m"; }
green() { echo -e "\033[32m$1\033[0m"; }
blue() { echo -e "\033[34m$1\033[0m"; }
cyan() { echo -e "\033[36m$1\033[0m"; }

# Configuration variables
NAMESPACE="gitlab-agent"
GITLAB_AGENT_HELM_REPO="https://charts.gitlab.io"
GITLAB_KAS_ADDRESS="wss://kas.gitlab.com" # Replace with your GitLab KAS address if self-hosted

# Function to send and execute commands on the remote VM
send_command_to_vm() {
    local command="$1"
    qm guest exec "$VM_ID" -- bash -c "$command"
}

# Step 1: Prompt for GitLab Agent details
prompt_gitlab_agent_details() {
    read -p "Enter QEMU VM ID: " VM_ID
    read -p "Enter GitLab Agent name: " AGENT_NAME
    read -p "Enter GitLab Agent token: " AGENT_TOKEN
}

# Step 2: Ensure Helm is installed on the VM
install_helm() {
    blue "Checking if Helm is installed on VM $VM_ID..."
    send_command_to_vm "command -v helm" || {
        blue "Installing Helm on VM $VM_ID..."
        send_command_to_vm "curl -sSL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash"
    }
    green "Helm is installed on VM $VM_ID."
}

# Step 3: Add the GitLab Helm repository
add_gitlab_helm_repo() {
    blue "Adding GitLab Helm repository on VM $VM_ID..."
    send_command_to_vm "helm repo add gitlab $GITLAB_AGENT_HELM_REPO && helm repo update"
    green "GitLab Helm repository added."
}

# Step 4: Install GitLab Agent in the specified namespace
install_gitlab_agent() {
    blue "Installing GitLab Agent ($AGENT_NAME) on VM $VM_ID..."

    send_command_to_vm "helm upgrade --install $AGENT_NAME gitlab/gitlab-agent \
        --namespace $NAMESPACE-$AGENT_NAME \
        --create-namespace \
        --set config.token=$AGENT_TOKEN \
        --set config.kasAddress=$GITLAB_KAS_ADDRESS"

    green "GitLab Agent ($AGENT_NAME) installed in namespace $NAMESPACE on VM $VM_ID."
}

# Main script
main() {
    prompt_gitlab_agent_details
    install_helm
    add_gitlab_helm_repo
    install_gitlab_agent
}

# Run the main function
main