#!/bin/bash

# Colors for output
red() { echo -e "\033[31m$1\033[0m"; }
green() { echo -e "\033[32m$1\033[0m"; }
blue() { echo -e "\033[34m$1\033[0m"; }
cyan() { echo -e "\033[36m$1\033[0m"; }

# Function to check for existing SSH key or create one if it doesn't exist
check_ssh_key() {
    blue "Checking for existing SSH key..."

    ssh_key_path="/root/.ssh/id_rsa"
    if [ ! -f "$ssh_key_path" ]; then
        echo "SSH key not found, generating new SSH key..."
        ssh-keygen -t rsa -b 4096 -f "$ssh_key_path" -N ""
        echo "SSH key created at $ssh_key_path"
    else
        echo "SSH key already exists at $ssh_key_path"
    fi
}

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

# Function to prompt for user input (disk, memory, swap, cores)
prompt_user_input() {
    blue "Initializing LXC container creation..."
    cyan "Please enter the following details to create the LXC container:"

    green "Enter the GitLab repo URL: "
    read gitlab_repo_url
    green "Enter disk size (in GB, e.g. 10) [default: 10]: "
    read -p "" disk_size
    disk_size=${disk_size:-10}
    green "Enter memory size (in MB, e.g. 2048) [default: 2048MB]: "
    read -p "" memory_size
    memory_size=${memory_size:-2048}
    green "Enter swap size (in MB, e.g. 512) [default: 512MB]: "
    read -p "" swap_size
    swap_size=${swap_size:-512}
    green "Enter number of cores (e.g. 2) [default: 2 cores]: "
    read -p "" cores
    cores=${cores:-2}
}

# Function to create LXC container with specified parameters
create_lxc_container() {
    container_id=$(get_next_id) # Get next available container ID
    blue "Creating LXC container with ID $container_id..."

    pct create "$container_id" \
        /var/lib/vz/template/cache/debian-12-standard_12.7-1_amd64.tar.zst \
        -description "GitLab Runner for $(basename "$gitlab_repo_url")" \
        -arch amd64 \
        -hostname $(basename "$gitlab_repo_url") \
        -rootfs local:"$disk_size" \
        -cores "$cores" \
        -memory "$memory_size" \
        -swap "$swap_size" \
        -net0 name=eth0,bridge=vmbr1,firewall=1,ip=dhcp \
        -ssh-public-keys "$ssh_key_path.pub" \
        -features nesting=1,keyctl=1 \
        -onboot 1

    if [ $? -ne 0 ]; then
        red "Error creating the LXC container."
        exit 1
    fi

    blue "Starting LXC container $container_id..."
    pct start "$container_id"
    blue "LXC container $container_id created and started."

    # Print the configuration of the created container
    blue "Configuration of LXC container $container_id:"
    pct config "$container_id"

    # Retrieve and display the DHCP-assigned IP address
    container_ip=$(pct exec "$container_id" -- hostname -I | awk '{print $1}')
    blue "DHCP-assigned IP address of LXC container $container_id: $container_ip"
}

# Function to install necessary packages (curl, Docker..) inside the LXC container
install_packages() {
    blue "Installing packages inside container $container_id..."

    pct exec "$container_id" -- bash -c "
        apt-get update &&
        apt-get install -y curl docker.io 
    "

    if [ $? -ne 0 ]; then
        red "Error installing packages for container $container_id."
        exit 1
    fi

    blue "Packages installed inside container $container_id."
}


# Function to install GitLab Runner inside the LXC container
install_gitlab_runner() {
    blue "Installing GitLab Runner inside container $container_id..."

    pct exec "$container_id" -- bash -c "
        curl -LJO https://s3.dualstack.us-east-1.amazonaws.com/gitlab-runner-downloads/latest/deb/gitlab-runner_amd64.deb &&
        dpkg -i gitlab-runner_amd64.deb &&
        rm gitlab-runner_amd64.deb &&
        gitlab-runner start
    "

    if [ $? -ne 0 ]; then
        red "Error installing GitLab Runner for container $container_id."
        exit 1
    fi

    blue "GitLab Runner installed & started inside container $container_id."
}

# Function to register GitLab Runner inside the container using authentication token
register_gitlab_runner() {
    blue "Registering GitLab Runner for container $container_id..."

    cyan "Instructions to create a GitLab Runner authentication token:"
    cyan "1. Navigate to your GitLab project."
    cyan "2. Go to 'Settings' > 'CI/CD'."
    cyan "3. Expand the 'Runners' section."
    cyan "4. Click 'New project runner' and setup a runner with the following settings:"
    cyan "  Tags: self-hosted"
    cyan "  Runner Description: 'Runner for $(basename "$gitlab_repo_url")'"
    cyan "  Protected: True"
    cyan "  Lock to current projects: True"
    cyan "5. Copy the 'Runer Authentication Token' (starts with glrt-). You will use this token in the next step."

    green "Enter your GitLab project authentication token for $(basename "$gitlab_repo_url"): "
    read gitlab_runner_token

    pct exec "$container_id" -- bash -c "
        gitlab-runner register \
        --non-interactive \
        --url https://gitlab.com/ \
        --token '$gitlab_runner_token' \
        --description 'Runner for $(basename "$gitlab_repo_url")' \
        --executor docker \
        --docker-image "docker:24.0.5" \
        --docker-privileged
    "
    if [ $? -ne 0 ]; then
        red "Error registering GitLab Runner for container $container_id."
        exit 1
    fi

    blue "GitLab Runner registered inside container $container_id."
}

# Main script execution
main() {
    blue "Creating LXC container with GitLab Runner for $(basename "$gitlab_repo_url")..."
    check_ssh_key
    prompt_user_input
    create_lxc_container
    install_packages
    install_gitlab_runner
    register_gitlab_runner
    blue "Container $container_id with GitLab Runner for $(basename "$gitlab_repo_url") created and registered successfully!"
}

# Run the main script
main