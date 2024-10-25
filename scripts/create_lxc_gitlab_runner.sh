#!/bin/bash

# Function to check for existing SSH key or create one if it doesn't exist
check_ssh_key() {
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
    echo "No available ID found in the range 900-999." >&2
    exit 1
}

# Function to prompt for user input (disk, memory, swap, cores)
prompt_user_input() {
    read -p "Enter the GitLab repo URL: " gitlab_repo_url
    read -p "Enter disk size (in GB, e.g. 10) [default: 10]: " disk_size
    disk_size=${disk_size:-10}
    read -p "Enter memory size (in MB, e.g. 2048) [default: 2048MB]: " memory_size
    memory_size=${memory_size:-2048}
    read -p "Enter swap size (in MB, e.g. 512) [default: 512MB]: " swap_size
    swap_size=${swap_size:-512}
    read -p "Enter number of cores (e.g. 2) [default: 2 cores]: " cores
    cores=${cores:-2}
}

# Function to create LXC container with specified parameters
create_lxc_container() {
    container_id=$(get_next_id) # Get next available container ID
    echo "Creating LXC container with ID $container_id..."

    pct create "$container_id" \
        /var/lib/vz/template/cache/debian-12-standard_12.7-1_amd64.tar.zst \
        -arch amd64 \
        -hostname $(basename "$gitlab_repo_url") \
        -cores "$cores" \
        -memory "$memory_size" \
        -swap "$swap_size" \
        -rootfs local:"$disk_size" \
        -net0 name=eth0,bridge=vmbr1,firewall=1,ip=dhcp \
        -ssh-public-keys "$ssh_key_path.pub" \
        -onboot 1

    if [ $? -ne 0 ]; then
        echo "Error creating the LXC container."
        exit 1
    fi

    pct start "$container_id"
    echo "LXC container $container_id created and started."
}

# Function to install necessary packages (curl, Docker..) inside the LXC container
install_packages() {
    echo "Installing packages inside container $container_id..."

    pct exec "$container_id" -- bash -c "
        apt-get update &&
        apt-get install -y curl docker.io 
    "

    if [ $? -ne 0 ]; then
        echo "Error installing packages for container $container_id."
        exit 1
    fi

    echo "Packages installed inside container $container_id."
}


# Function to install GitLab Runner inside the LXC container
install_gitlab_runner() {
    echo "Installing GitLab Runner inside container $container_id..."

    pct exec "$container_id" -- bash -c "
        curl -LJO https://s3.dualstack.us-east-1.amazonaws.com/gitlab-runner-downloads/latest/deb/gitlab-runner_amd64.deb &&
        dpkg -i gitlab-runner_amd64.deb &&
        rm gitlab-runner_amd64.deb &&
        gitlab-runner start
    "

    if [ $? -ne 0 ]; then
        echo "Error installing GitLab Runner for container $container_id."
        exit 1
    fi

    echo "GitLab Runner installed & started inside container $container_id."
}

# Function to register GitLab Runner inside the container using authentication token
register_gitlab_runner() {
    echo "Registering GitLab Runner for container $container_id..."

    echo "Instructions to create a GitLab Runner authentication token:"
    echo "1. Navigate to your GitLab project."
    echo "2. Go to 'Settings' > 'CI/CD'."
    echo "3. Expand the 'Runners' section."
    echo "4. Click 'New project runner' and setup a runner with the following settings:"
    echo "  Tags: self-hosted"
    echo "  Runner Description: 'Runner for $(basename "$gitlab_repo_url")'"
    echo "  Protected: True"
    echo "  Lock to current projects: True"
    echo "5. Copy the 'Runer Authentication Token' (starts with glrt-). You will use this token in the next step."

    read -p "Enter your GitLab project authentication token for $(basename "$gitlab_repo_url"): " gitlab_runner_token

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
        echo "Error registering GitLab Runner for container $container_id."
        exit 1
    fi

    echo "GitLab Runner registered inside container $container_id."
}

# Main script execution
main() {
    check_ssh_key
    prompt_user_input
    create_lxc_container
    install_packages
    install_gitlab_runner
    register_gitlab_runner
    echo "Container $container_id ith GitLab Runner for $(basename "$gitlab_repo_url") created and registered successfully!"
}

# Run the main script
main