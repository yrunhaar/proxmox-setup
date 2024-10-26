#!/bin/bash

# Colors for output
red() { echo -e "\033[31m$1\033[0m"; }
green() { echo -e "\033[32m$1\033[0m"; }
blue() { echo -e "\033[34m$1\033[0m"; }
cyan() { echo -e "\033[36m$1\033[0m"; }

# Variables
DEBIAN_CLOUD_IMAGE="debian-12-genericcloud-amd64.qcow2"
IMAGE_URL="https://cloud.debian.org/images/cloud/bookworm/latest/$DEBIAN_CLOUD_IMAGE"
STORAGE_PATH="/var/lib/vz/template/qcow2"
VM_STORAGE="local-lvm"
VM_BRIDGE="vmbr1"
VM_USER="admin"
VM_PASSWORD=$(openssl rand -base64 16)  # Generate a strong random password

# Function to check for existing SSH key or create one if it doesn't exist
check_ssh_key() {
    blue "Checking for existing SSH key..."
    ssh_key_path="/root/.ssh/id_rsa"
    if [ ! -f "$ssh_key_path" ]; then
        ssh-keygen -t rsa -b 4096 -f "$ssh_key_path" -N ""
        green "SSH key created at $ssh_key_path"
    else
        green "SSH key already exists at $ssh_key_path"
    fi
}

# Function to get the next available VM ID in the 100 range
get_next_id() {
    for id in {100..199}; do
        if ! qm status $id &>/dev/null; then
            echo $id
            return
        fi
    done
    red "No available VM ID found in the range 100-199."
    exit 1
}

# Function to download Debian cloud image if not present
download_image() {
    if [ ! -f "$STORAGE_PATH/$DEBIAN_CLOUD_IMAGE" ]; then
        blue "Downloading Debian cloud image..."
        mkdir -p "$STORAGE_PATH"
        wget -O "$STORAGE_PATH/$DEBIAN_CLOUD_IMAGE" "$IMAGE_URL"
        if [ $? -ne 0 ]; then
            red "Error downloading Debian cloud image."
            exit 1
        fi
        green "Download complete: $STORAGE_PATH/$DEBIAN_CLOUD_IMAGE"
    else
        green "Debian cloud image already exists at $STORAGE_PATH/$DEBIAN_CLOUD_IMAGE"
    fi
}

# Function to prompt for user input (disk, memory, cores)
prompt_user_input() {
    blue "Initializing VM creation..."
    cyan "Please enter the following details to create the VM:"
    read -p "Enter the GitLab repo URL: " gitlab_repo_url
    read -p "Enter disk size (in GB, e.g. 10) [default: 10]: " disk_size
    disk_size=${disk_size:-10}
    read -p "Enter memory size (in MB, e.g. 2048) [default: 2048MB]: " memory_size
    memory_size=${memory_size:-2048}
    read -p "Enter number of cores (e.g. 2) [default: 2 cores]: " cores
    cores=${cores:-2}
}

# Function to create VM with specified parameters and Debian cloud image
create_vm() {
    VM_ID=$(get_next_id) # Get next available container ID
    blue "Creating VM with ID $VM_ID and importing the Debian cloud image..."

    # Create VM
    qm create "$VM_ID" --name "GitLabRunnerVM" --memory "$memory_size" --cores "$cores" --net0 virtio,bridge="$VM_BRIDGE"

    # Import the Debian cloud image as a disk for the new VM
    qm importdisk "$VM_ID" "$STORAGE_PATH/$DEBIAN_CLOUD_IMAGE" "$VM_STORAGE"
    qm set "$VM_ID" --scsihw virtio-scsi-pci --scsi0 "$VM_STORAGE:vm-$VM_ID-disk-0"
    qm set "$VM_ID" --ide2 "$VM_STORAGE:cloudinit"
    qm set "$VM_ID" --boot c --bootdisk scsi0
    qm set "$VM_ID" --serial0 socket --vga serial0
    qm set "$VM_ID" --ciuser "$VM_USER" --cipassword "$VM_PASSWORD" --ipconfig0 ip=dhcp

    # Prompt user to save the password
    cyan "Generated VM password for emergency access. Please copy and store securely: $VM_PASSWORD"

    green "VM $VM_ID created and configured with cloud-init."

    # Start VM
    blue "Starting VM $VM_ID..."
    qm start "$VM_ID"
    blue "VM $VM_ID started."
}

# Function to retrieve the IP address of the VM
get_vm_ip() {
    blue "Waiting for VM to acquire IP..."
    sleep 15  # Wait for the VM to start and get an IP address
    VM_IP=$(qm guest exec "$VM_ID" -- ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
    if [ -z "$VM_IP" ]; then
        red "Failed to retrieve VM IP address."
        exit 1
    fi
    green "VM IP Address: $VM_IP"
}

# Function to copy SSH key to VM
copy_ssh_key() {
    blue "Copying SSH key to VM..."
    sshpass -p "$VM_PASSWORD" ssh-copy-id -i /root/.ssh/id_rsa.pub -o StrictHostKeyChecking=no "$VM_USER@$VM_IP"
    if [ $? -ne 0 ]; then
        red "Error copying SSH key to VM."
        exit 1
    fi
    green "SSH key copied to VM. You can now log in with SSH key access."
}

# Function to install necessary packages (Docker, GitLab Runner) on the VM
install_packages_vm() {
    blue "Installing Docker and GitLab Runner on VM $VM_ID at $VM_IP..."
    ssh "$VM_USER@$VM_IP" <<EOF
        sudo apt-get update &&
        sudo apt-get install -y docker.io curl &&
        curl -L --output gitlab-runner.deb https://s3.dualstack.us-east-1.amazonaws.com/gitlab-runner-downloads/latest/deb/gitlab-runner_amd64.deb &&
        sudo dpkg -i gitlab-runner.deb &&
        sudo rm gitlab-runner.deb &&
        sudo gitlab-runner start
EOF
    if [ $? -ne 0 ]; then
        red "Error installing packages on VM $VM_ID."
        exit 1
    fi
    green "Packages installed on VM $VM_ID."
}

# Function to register GitLab Runner on the VM using authentication token
register_gitlab_runner_vm() {
    blue "Registering GitLab Runner on VM $VM_ID at $VM_IP..."

    cyan "Instructions to create a GitLab Runner authentication token:"
    cyan "1. Navigate to your GitLab project."
    cyan "2. Go to 'Settings' > 'CI/CD'."
    cyan "3. Expand the 'Runners' section."
    cyan "4. Click 'New project runner' and setup a runner with the following settings:"
    cyan "  Tags: self-hosted"
    cyan "  Runner Description: 'Runner for $(basename "$gitlab_repo_url")'"
    cyan "  Protected: True"
    cyan "  Lock to current projects: True"
    cyan "5. Copy the 'Runner Authentication Token' (starts with glrt-). You will use this token in the next step."

    read -p "Enter your GitLab project authentication token for $(basename "$gitlab_repo_url"): " gitlab_runner_token

    ssh "$VM_USER@$VM_IP" <<EOF
        sudo gitlab-runner register \
        --non-interactive \
        --url https://gitlab.com/ \
        --token "$gitlab_runner_token" \
        --description 'Runner for $(basename "$gitlab_repo_url")' \
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

# Main script execution
main() {
    check_ssh_key
    download_image
    prompt_user_input
    create_vm
    get_vm_ip
    copy_ssh_key
    install_packages_vm
    register_gitlab_runner_vm
    green "Setup complete! VM $VM_ID with GitLab Runner for $(basename "$gitlab_repo_url") created, configured, and registered successfully!"
}

# Run the main script
main