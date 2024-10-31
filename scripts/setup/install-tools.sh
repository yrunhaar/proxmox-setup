#!/bin/bash

# Colored output functions
red() { echo -e "\033[31m$1\033[0m"; }
green() { echo -e "\033[32m$1\033[0m"; }
blue() { echo -e "\033[34m$1\033[0m"; }
cyan() { echo -e "\033[36m$1\033[0m"; }

# Function to update and install prerequisites
function install_prerequisites {
    blue "Updating and installing prerequisites..."
    sudo apt update
    sudo apt install -y gnupg software-properties-common curl wget
    green "Prerequisites installed."
}

# Function to install Packer
function install_packer {
    blue "Installing Packer..."
    wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt update && sudo apt install -y packer
    packer -v && green "Packer installed."
}

# Function to install Terraform
function install_terraform {
    blue "Installing Terraform..."
    wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt update && sudo apt install -y terraform
    terraform -v && green "Terraform installed."
}

# Function to install Talosctl
function install_talosctl {
    blue "Installing Talosctl..."
    curl -sL https://talos.dev/install | sh
    talosctl version --help && green "Talosctl installed."
}

# Function to install Talhelper
function install_talhelper {
    blue "Installing Talhelper..."
    curl https://i.jpillora.com/budimanjojo/talhelper! | sudo bash
    talhelper -v && green "Talhelper installed."
}

# Function to install Kubectl
function install_kubectl {
    blue "Installing Kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    kubectl version --client && green "Kubectl installed."
}

# Function to install Sops
function install_sops {
    blue "Installing Sops..."
    curl -LO https://github.com/getsops/sops/releases/download/v3.8.1/sops-v3.8.1.linux.amd64
    sudo mv sops-v3.8.1.linux.amd64 /usr/local/bin/sops
    sudo chmod +x /usr/local/bin/sops
    sops -v && green "Sops installed."
}

# Function to install Age
function install_age {
    blue "Installing Age..."
    sudo apt install -y age
    age -version && green "Age installed."
}

# Function to install Cilium CLI
function install_cilium_cli {
    blue "Installing Cilium CLI..."
    CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
    CLI_ARCH=amd64
    if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
    curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
    sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
    sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
    rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
    green "Cilium CLI installed."
}

# Main installation process
cyan "Starting tool installation..."

install_prerequisites
install_packer
install_terraform
install_talosctl
install_talhelper
install_kubectl
install_sops
install_age
install_cilium_cli

green "All tools have been successfully installed."