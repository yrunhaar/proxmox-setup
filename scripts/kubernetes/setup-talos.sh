#!/bin/bash

# Default configuration values
VM_ID=300
PROXMOX_NODE="pve"        # Default Proxmox node name
DISK_SIZE="32G"
MEMORY="16384"            # 16 GB RAM
CPU="8"
STORAGE_POOL="local"      # Default storage pool
BRIDGE="vmbr1"            # Default network bridge

# URLs for Talos
TALOS_VERSION="v1.8.2"
TALOS_ISO_URL="https://github.com/siderolabs/talos/releases/download/${TALOS_VERSION}/metal-amd64.iso"
TALOS_ISO_NAME="talos-${TALOS_VERSION}-amd64.iso"

# Colored echo functions
red() { echo -e "\033[31m$1\033[0m"; }
green() { echo -e "\033[32m$1\033[0m"; }
blue() { echo -e "\033[34m$1\033[0m"; }
cyan() { echo -e "\033[36m$1\033[0m"; }

# Function to prompt for user inputs with defaults
function prompt_for_inputs {
    cyan "Prompting for configuration values..."

    read -p "Enter Proxmox VM ID (default: $VM_ID): " input_vm_id
    VM_ID="${input_vm_id:-$VM_ID}"

    read -p "Enter Proxmox Node (default: $PROXMOX_NODE): " input_node
    PROXMOX_NODE="${input_node:-$PROXMOX_NODE}"

    read -p "Enter Disk Size (default: $DISK_SIZE): " input_disk_size
    DISK_SIZE="${input_disk_size:-$DISK_SIZE}"

    read -p "Enter Memory in MB (default: $MEMORY): " input_memory
    MEMORY="${input_memory:-$MEMORY}"

    read -p "Enter CPU Cores (default: $CPU): " input_cpu
    CPU="${input_cpu:-$CPU}"

    read -p "Enter Storage Pool (default: $STORAGE_POOL): " input_storage_pool
    STORAGE_POOL="${input_storage_pool:-$STORAGE_POOL}"

    read -p "Enter Network Bridge (default: $BRIDGE): " input_bridge
    BRIDGE="${input_bridge:-$BRIDGE}"
}

# Function to download Talos ISO if not already present
function download_talos_iso {
    blue "Checking for Talos ISO in Proxmox storage pool..."
    if pvesm list "$STORAGE_POOL" | grep -q "$TALOS_ISO_NAME"; then
        green "Talos ISO already exists in $STORAGE_POOL. Skipping download."
    else
        blue "Downloading Talos ISO from official source..."
        wget -q --show-progress -O "/var/lib/vz/template/iso/$TALOS_ISO_NAME" "$TALOS_ISO_URL"
        green "Download completed."
    fi
}

# Function to create the Proxmox VM for Talos
function create_proxmox_vm {
    blue "Creating Proxmox VM with Talos ISO attached..."

    qm create "$VM_ID" --name talos --memory "$MEMORY" --cores "$CPU" --net0 virtio,bridge="$BRIDGE" --cdrom "$STORAGE_POOL:iso/$TALOS_ISO_NAME" --scsihw virtio-scsi-pci --scsi0 "$STORAGE_POOL:$DISK_SIZE"

    green "VM $VM_ID created with Talos ISO attached. Adjust VM hardware as needed."
}

# Function to set up and install Talos
function configure_talos {
    blue "Configuring Talos for Kubernetes setup..."

    # Set CPU type if required for newer PVE versions
    qm set "$VM_ID" --cpu cputype=x86-64-v2

    # Set Qemu Agent and SCSI single controller
    qm set "$VM_ID" --agent 1 --scsihw virtio-scsi-single

    # Create and apply Talos configuration
    blue "Generating Talos configuration..."
    talosctl gen secrets
    talosctl gen config demo-cluster "https://10.0.10.10:6443" --output rendered/

    green "Talos configuration files created. Apply the configuration to nodes after booting the VM."
}

# Function to print next steps for the user
function display_next_steps {
    cyan "Next steps:"
    echo "1. Start the VM in Proxmox and open its console."
    echo "2. Boot into Talos and observe the setup process."
    echo "3. Once the VM is up, apply the configuration using talosctl commands."
    echo "4. Regularly back up etcd for disaster recovery."
    echo "5. Configure and test your Kubernetes cluster as required."

    green "Script complete. Talos is ready to manage your Kubernetes applications."
}

# Main function to execute the setup steps
function main {
    prompt_for_inputs
    download_talos_iso
    create_proxmox_vm
    configure_talos
    display_next_steps
}

# Run the script
main