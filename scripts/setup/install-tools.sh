#!/bin/bash

# Color functions for output
red() { echo -e "[31m$1[0m"; }
green() { echo -e "[32m$1[0m"; }
blue() { echo -e "[34m$1[0m"; }

# Install prerequisites
install_prerequisites() {
    blue "Installing prerequisites..."
    sudo apt update
    sudo apt install -y gnupg software-properties-common curl wget apt-transport-https ca-certificates lsb-release
    green "Prerequisites installed."
}

# Install Packer
install_packer() {
    blue "Installing Packer..."
    wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt update && sudo apt install packer
    packer -v
    green "Docker installed."
}

# Install Terraform
install_terraform() {
    blue "Installing Terraform..."
    wget -O- https://apt.releases.hashicorp.com/gpg | \
    gpg --dearmor | \
    sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
    https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
    sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt update
    sudo apt install terraform
    terraform -v
    green "Terraform installed."
}

# Install Talosctl
install_talosctl() {
    blue "Installing Talosctl..."
    curl -sL https://talos.dev/install | sh
    talosctl version --help
    green "Talosctl installed."
}

# Install Talhelper
install_talhelper() {
    blue "Installing Talhelper..."
    curl https://i.jpillora.com/budimanjojo/talhelper! | sudo bash
    talhelper -v
    green "Talhelper installed."
}

# Install Kubernetes CLI tools
install_kubectl() {
    blue "Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    kubectl version --client
    green "kubectl installed."
}

# Install SOPS for secrets management
install_sops() {
    blue "Installing SOPS for secrets management..."
    curl -LO https://github.com/getsops/sops/releases/download/v3.8.1/sops-v3.8.1.linux.amd64
    mv sops-v3.8.1.linux.amd64 /usr/local/bin/sops
    chmod +x /usr/local/bin/sops
    sops -v
    green "SOPS installed."
}

# Install Age
install_age() {
    blue "Installing Age..."
    sudo apt install age
    age -version
    green "Age installed."
}

# Install Cilium CLI
install_cilium_cli() {
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