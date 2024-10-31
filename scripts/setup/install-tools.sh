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

# Install Docker
install_docker() {
    blue "Installing Docker..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io
    sudo systemctl start docker
    sudo systemctl enable docker
    green "Docker installed."
}

# Install Terraform
install_terraform() {
    blue "Installing Terraform..."
    curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt update && sudo apt install -y terraform
    terraform -version && green "Terraform installed."
}

# Install Kubernetes CLI tools
install_kubectl() {
    blue "Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    green "kubectl installed."
}

# Install Prometheus, Grafana, and Loki (for logging and monitoring)
install_monitoring_tools() {
    blue "Installing Prometheus, Grafana, and Loki..."
    sudo docker pull prom/prometheus
    sudo docker pull grafana/grafana
    sudo docker pull grafana/loki
    green "Monitoring tools installed."
}

# Install SOPS for secrets management
install_sops() {
    blue "Installing SOPS for secrets management..."
    curl -Lo sops https://github.com/mozilla/sops/releases/download/v3.7.1/sops-v3.7.1.linux
    sudo install -o root -g root -m 0755 sops /usr/local/bin/sops
    green "SOPS installed."
}

# Install Talosctl
install_talosctl() {
    blue "Installing Talosctl..."
    curl -sL https://talos.dev/install | sh
    green "Talosctl installed."
}

# Install Helm for managing Kubernetes applications
install_helm() {
    blue "Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
    green "Helm installed."
}

# Main function to call each tool installation
main() {
    install_prerequisites
    install_docker
    install_terraform
    install_kubectl
    install_monitoring_tools
    install_sops
    install_talosctl
    install_helm
}

main