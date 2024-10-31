#!/bin/bash

# Color functions for output
green() { echo -e "\033[32m$1\033[0m"; }
blue() { echo -e "\033[34m$1\033[0m"; }
red() { echo -e "\033[31m$1\033[0m"; }

# Fetch dynamically assigned IPs directly from Terraform output
fetch_ips() {
    blue "Fetching dynamically assigned IPs from Terraform output..."
    
    CONTROL_PLANE_IPS=$(terraform output -json control_plane_ips | jq -r '.[]')
    WORKER_IPS=$(terraform output -json worker_ips | jq -r '.[]')

    if [ -z "$CONTROL_PLANE_IPS" ] || [ -z "$WORKER_IPS" ]; then
        red "Failed to retrieve IPs from Terraform output. Ensure Terraform has applied the resources."
        exit 1
    fi

    green "Control Plane IPs: $CONTROL_PLANE_IPS"
    green "Worker Node IPs: $WORKER_IPS"
}

# Generate Talos secrets and configurations using dynamically assigned IPs
generate_and_apply_talos_config() {
    blue "Generating Talos secrets and configurations..."
    
    talosctl gen secrets -o talos-secrets.yaml
    talosctl gen config demo-cluster https://"${CONTROL_PLANE_IPS%% *}":6443 --output config --with-secrets talos-secrets.yaml

    # Apply configuration to each control plane node
    for ip in $CONTROL_PLANE_IPS; do
        blue "Applying Talos configuration to control plane node: $ip"
        talosctl apply-config --insecure --nodes "$ip" --file config/controlplane.yaml || {
            red "Failed to apply config to control plane node $ip."
            exit 1
        }
    done

    # Apply configuration to each worker node
    for ip in $WORKER_IPS; do
        blue "Applying Talos configuration to worker node: $ip"
        talosctl apply-config --insecure --nodes "$ip" --file config/worker.yaml || {
            red "Failed to apply config to worker node $ip."
            exit 1
        }
    done

    green "Talos configuration applied successfully to all nodes."
}

# Main function
main() {
    fetch_ips
    generate_and_apply_talos_config
}

# Run the main function
main