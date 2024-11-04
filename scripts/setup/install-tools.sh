#!/bin/bash

# Color functions for output
red() { echo -e "\033[31m$1\033[0m"; }
green() { echo -e "\033[32m$1\033[0m"; }
blue() { echo -e "\033[34m$1\033[0m"; }

# Install prerequisites
install_prerequisites() {
    blue "Installing prerequisites..."
    sudo apt update
    sudo apt install -y gnupg software-properties-common curl wget apt-transport-https ca-certificates lsb-release jq
    green "Prerequisites installed."
}

# Install Docker
install_docker() {
    if ! command -v docker &> /dev/null; then
        blue "Installing Docker..."
        sudo apt install -y docker.io
        sudo systemctl enable --now docker
        sudo usermod -aG docker $USER
        docker --version
        green "Docker installed."
    else
        green "Docker is already installed."
    fi
}

# Install Packer
install_packer() {
    if ! command -v packer &> /dev/null; then
        blue "Installing Packer..."
        if [ ! -f /usr/share/keyrings/hashicorp-archive-keyring.gpg ]; then
            wget -qO- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
        fi
        echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null
        sudo apt update && sudo apt install -y packer
        packer -v
        green "Packer installed."
    else
        green "Packer is already installed."
    fi
}

# Install Terraform
install_terraform() {
    if ! command -v terraform &> /dev/null; then
        blue "Installing Terraform..."
        if [ ! -f /usr/share/keyrings/hashicorp-archive-keyring.gpg ]; then
            wget -qO- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
        fi
        echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null
        sudo apt update && sudo apt install -y terraform
        terraform -v
        green "Terraform installed."
    else
        green "Terraform is already installed."
    fi
}

# Install Talosctl
install_talosctl() {
    if ! command -v talosctl &> /dev/null; then
        blue "Installing Talosctl..."
        curl -sL https://talos.dev/install | sh
        talosctl version
        green "Talosctl installed."
    else
        green "Talosctl is already installed."
    fi
}

# Install Talhelper
install_talhelper() {
    if ! command -v talhelper &> /dev/null; then
        blue "Installing Talhelper..."
        curl https://i.jpillora.com/budimanjojo/talhelper! | sudo bash
        talhelper -v
        green "Talhelper installed."
    else
        green "Talhelper is already installed."
    fi
}

# Install Kubernetes CLI tools
install_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        blue "Installing kubectl..."
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
        kubectl version --client
        green "kubectl installed."
    else
        green "kubectl is already installed."
    fi
}

# Install SOPS for secrets management
install_sops() {
    if ! command -v sops &> /dev/null; then
        blue "Installing SOPS for secrets management..."
        curl -LO https://github.com/getsops/sops/releases/download/v3.8.1/sops-v3.8.1.linux.amd64
        sudo mv sops-v3.8.1.linux.amd64 /usr/local/bin/sops
        sudo chmod +x /usr/local/bin/sops
        sops -v
        green "SOPS installed."
    else
        green "SOPS is already installed."
    fi
}

# Install Age
install_age() {
    if ! command -v age &> /dev/null; then
        blue "Installing Age..."
        sudo apt install -y age
        age -version
        green "Age installed."
    else
        green "Age is already installed."
    fi
}

# Install Cilium CLI
install_cilium_cli() {
    if ! command -v cilium &> /dev/null; then
        blue "Installing Cilium CLI..."
        CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
        CLI_ARCH=amd64
        if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
        curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
        sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
        sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
        rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
        green "Cilium CLI installed."
    else
        green "Cilium CLI is already installed."
    fi
}

# Install Prometheus, Grafana, and Loki (for logging and monitoring)
install_monitoring_tools() {
    blue "Installing Prometheus, Grafana, and Loki..."
    sudo docker pull prom/prometheus
    sudo docker pull grafana/grafana
    sudo docker pull grafana/loki
    green "Monitoring tools installed."
}

# Main function
main() {
    install_prerequisites
    install_docker
    install_packer
    install_terraform
    install_talosctl
    install_talhelper
    install_kubectl
    install_sops
    install_age
    install_cilium_cli
    install_monitoring_tools
}

# Call the main function
main