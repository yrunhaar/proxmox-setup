#!/bin/bash

# Color output functions for better readability
red() { echo -e "\033[31m$1\033[0m"; }
green() { echo -e "\033[32m$1\033[0m"; }
blue() { echo -e "\033[34m$1\033[0m"; }
cyan() { echo -e "\033[36m$1\033[0m"; }

# Define paths
OUTPUT_DIR="/tmp/proxmox-setup"
OUTPUT_FILE="$OUTPUT_DIR/terraform_output.txt"

# Define paths
TALOS_DIR="$HOME/talos"
TALOS_CONFIG_DIR="$TALOS_DIR/clusterconfig"
TALOS_CONFIG_FILE="$HOME/.talos/config"
METALLB_CONFIG_DIR="$HOME/.metallb"
KUBE_CONFIG_DIR="$HOME/.kube"
KUBE_CONFIG_FILE="$KUBE_CONFIG_DIR/config"
CONFIG_DIR="$HOME/.config"
SOPS_CONFIG_DIR="$CONFIG_DIR/sops"
AGE_CONFIG_DIR="$SOPS_CONFIG_DIR/age"

# Function to create directories if they don't exist
ensure_directories() {
    local dirs=("$TALOS_DIR" "$TALOS_CONFIG_DIR" "$METALLB_CONFIG_DIR" "$KUBE_CONFIG_DIR" "$CONFIG_DIR" "$SOPS_CONFIG_DIR" "$AGE_CONFIG_DIR")

    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir" && green "Created directory: $dir" || red "Failed to create directory: $dir"
            chmod -R 700 "$dir" || red "Failed to set permissions for directory: $dir"
        else
            blue "Directory already exists: $dir"
        fi
    done
}

# Call the function to ensure directories
ensure_directories

# Load values from the output file
if [[ -f "$OUTPUT_FILE" ]]; then
    MASTER_VMIDS=($(jq -r '.master_vmids.value[]' "$OUTPUT_FILE"))
    MASTER_MACS=($(jq -r '.master_macaddrs.value[]' "$OUTPUT_FILE"))
    WORKER_VMIDS=($(jq -r '.worker_vmids.value[]' "$OUTPUT_FILE"))
    WORKER_MACS=($(jq -r '.worker_macaddrs.value[]' "$OUTPUT_FILE"))
    MASTER_IPS=($(jq -r '.master_ips[]' "$OUTPUT_FILE"))
    WORKER_IPS=($(jq -r '.worker_ips[]' "$OUTPUT_FILE"))
    TALOS_VERSION=$(jq -r '.talos_version.value' "$OUTPUT_FILE")
    TALOS_DISK_IMAGE_ID=$(jq -r '.talos_disk_image_id.value' "$OUTPUT_FILE")

    blue "Loaded values from $OUTPUT_FILE"
else
    red "Error: Output file $OUTPUT_FILE not found."
    exit 1
fi

# Display loaded values
cyan "Master VM IDs: ${MASTER_VMIDS[@]}"
cyan "Master IPs: ${MASTER_IPS[@]}"
cyan "Master MACs: ${MASTER_MACS[@]}"
cyan "Worker VM IDs: ${WORKER_VMIDS[@]}"
cyan "Worker IPs: ${WORKER_IPS[@]}"
cyan "Worker MACs: ${WORKER_MACS[@]}"
cyan "Talos Version: $TALOS_VERSION"
cyan "Talos Disk Image ID: $TALOS_DISK_IMAGE_ID"

# Step 1: Generate Talos YAML configuration for cluster setup
generate_talos_yaml_config() {
    blue "Generating Talos cluster configuration YAML file..."

    cat > "$TALOS_DIR/talconfig.yaml" <<EOF
# yaml-language-server: \$schema=https://raw.githubusercontent.com/budimanjojo/talhelper/master/pkg/config/schemas/talconfig.json
---
talosVersion: "${TALOS_VERSION}"
kubernetesVersion: "v1.30.0"

clusterName: "cluster-01"
endpoint: "https://192.168.1.50:6443"
clusterPodNets:
  - "10.14.0.0/16"
clusterSvcNets:
  - "10.15.0.0/16"
additionalApiServerCertSans:
  - "192.168.1.50"
additionalMachineCertSans:
  - "192.168.1.50"

nodes:
  - hostname: "talos-master-00"
    controlPlane: true
    ipAddress: "${MASTER_IPS[0]}"
    installDisk: "/dev/sda"
    talosImageURL: "factory.talos.dev/installer/${TALOS_DISK_IMAGE_ID}:${TALOS_VERSION}"
    networkInterfaces:
      - deviceSelector:
          hardwareAddr: "${MASTER_MACS[0]}"
        dhcp: true
        vip:
          ip: "192.168.1.50"

  - hostname: "talos-master-01"
    controlPlane: true
    ipAddress: "${MASTER_IPS[1]}"
    installDisk: "/dev/sda"
    talosImageURL: "factory.talos.dev/installer/${TALOS_DISK_IMAGE_ID}:${TALOS_VERSION}"
    networkInterfaces:
      - deviceSelector:
          hardwareAddr: "${MASTER_MACS[1]}"
        dhcp: true
        vip:
          ip: "192.168.1.50"

  - hostname: "talos-master-02"
    controlPlane: true
    ipAddress: "${MASTER_IPS[2]}"
    installDisk: "/dev/sda"
    talosImageURL: "factory.talos.dev/installer/${TALOS_DISK_IMAGE_ID}:${TALOS_VERSION}"
    networkInterfaces:
      - deviceSelector:
          hardwareAddr: "${MASTER_MACS[2]}"
        dhcp: true
        vip:
          ip: "192.168.1.50"

  - hostname: "talos-worker-00"
    controlPlane: false
    ipAddress: "${WORKER_IPS[0]}"
    installDisk: "/dev/sda"
    talosImageURL: "factory.talos.dev/installer/${TALOS_DISK_IMAGE_ID}:${TALOS_VERSION}"
    networkInterfaces:
      - deviceSelector:
          hardwareAddr: "${WORKER_MACS[0]}"
        dhcp: true

  - hostname: "talos-worker-01"
    controlPlane: false
    ipAddress: "${WORKER_IPS[1]}"
    installDisk: "/dev/sda"
    talosImageURL: "factory.talos.dev/installer/${TALOS_DISK_IMAGE_ID}:${TALOS_VERSION}"
    networkInterfaces:
      - deviceSelector:
          hardwareAddr: "${WORKER_MACS[1]}"
        dhcp: true

  - hostname: "talos-worker-02"
    controlPlane: false
    ipAddress: "${WORKER_IPS[2]}"
    installDisk: "/dev/sda"
    talosImageURL: "factory.talos.dev/installer/${TALOS_DISK_IMAGE_ID}:${TALOS_VERSION}"
    networkInterfaces:
      - deviceSelector:
          hardwareAddr: "${WORKER_MACS[2]}"
        dhcp: true

controlPlane:
  patches:
    - |-
      cluster:
        controllerManager:
          extraArgs:
            bind-address: "0.0.0.0"
        scheduler:
          extraArgs:
            bind-address: "0.0.0.0"

worker:
  patches:
    - |-
      machine:
        kubelet:
          extraMounts:
            - destination: "/var/mnt/longhorn"
              type: "bind"
              source: "/var/mnt/longhorn"
              options:
                - "bind"
                - "rshared"
                - "rw"
        disks:
          - device: "/dev/sdb"
            partitions:
              - mountpoint: "/var/mnt/longhorn"
EOF
}


# Step 2: Generate Talos configuration using Talhelper
generate_talos_config() {
    cd "$TALOS_DIR" || exit

    # Generate Talos secret
    blue "Generating Talos secrets..."
    talhelper gensecret > talsecret.sops.yaml

    # Set Age key path for sops
    export SOPS_AGE_KEY_FILE="$AGE_CONFIG_DIR/keys.txt"

    # Create Age secret key for Sops
    blue "Creating Age secret key..."
    # Generate Age key with appropriate permissions
    if age-keygen -o "$AGE_CONFIG_DIR/keys.txt"; then
        chmod 600 "$AGE_CONFIG_DIR/keys.txt"  # Ensure key file is accessible
        green "Age key generated and permissions set successfully."
    else
        red "Failed to generate Age key."
        exit 1
    fi

    # Extract Age keys and format them without quotes
    AGE_KEY=$(grep -o 'age1.*' $AGE_CONFIG_DIR/keys.txt)

    # Create .sops.yaml configuration for Sops with properly formatted keys
    cat <<EOF > "$TALOS_DIR/.sops.yaml"
---
creation_rules:
  - age: >-
      $AGE_KEY
EOF

    # Encrypt Talos secrets with Age and Sops
    blue "Encrypting Talos secrets..."
    sops -e -i talsecret.sops.yaml || { red "Failed to encrypt Talos secrets"; exit 1; }
    green "Talos secrets encrypted in $TALOS_DIR."

    # Generate Talos configuration files
    blue "Generating Talos configuration files..."
    talhelper genconfig
    green "Talos configuration files generated in $TALOS_CONFIG_DIR."
}

# Step 3: Apply Talos configuration to nodes
apply_talos_config() {
    blue "Applying Talos configuration to master and worker nodes..."
    cd "$TALOS_CONFIG_DIR" || exit

    # Apply configuration for each master node
    for i in "${!MASTER_IPS[@]}"; do
        master_ip="${MASTER_IPS[$i]}"
        config_file="$TALOS_CONFIG_DIR/cluster-01-talos-master-$(printf '%02d' "$i").yaml"
        blue "Applying configuration to master node at $master_ip"
        talosctl apply-config --insecure --nodes "$master_ip" --file "$config_file"
    done

    # Apply configuration for each worker node
    for i in "${!WORKER_IPS[@]}"; do
        worker_ip="${WORKER_IPS[$i]}"
        config_file="$TALOS_CONFIG_DIR/cluster-01-talos-worker-$(printf '%02d' "$i").yaml"
        blue "Applying configuration to worker node at $worker_ip"
        talosctl apply-config --insecure --nodes "$worker_ip" --file "$config_file"
    done

    green "Configuration applied to all nodes. Waiting for nodes to reboot..."
    sleep 120  # Adjust this if nodes need more time to reboot
}

# Step 4: Bootstrap Talos on the cluster
bootstrap_talos_cluster() {
    local master_node_ip="${MASTER_IPS[0]}"

    # Set up Talos configuration
    mkdir -p "$(dirname "$TALOS_CONFIG_FILE")"
    cp "$TALOS_CONFIG_DIR/talosconfig" "$TALOS_CONFIG_FILE"

    # Run the bootstrap command on the first master node
    blue "Bootstrapping Talos on master node at IP $master_node_ip"
    talosctl bootstrap -n "$master_node_ip"

    # Generate kubeconfig for accessing the cluster
    mkdir -p "$KUBE_CONFIG_DIR"
    talosctl -n "$master_node_ip" kubeconfig "$KUBE_CONFIG_FILE"
    green "Kubeconfig saved to $KUBE_CONFIG_FILE"

    green "Configuration applied to all nodes. Waiting for nodes to reboot..."
    sleep 120  # Adjust this if nodes need more time to reboot

    # Verify node status
    cyan "Verifying the status of nodes..."
    kubectl get nodes
}

# Step 5: Configure MetalLB IP Pool
configure_metallb() {
    blue "Configuring MetalLB IP Pool..."
    cat > "$METALLB_CONFIG_DIR/metallb-values.yaml" <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: metallb
data:
  config: |
    peers:
    - peer-address: 192.168.1.1
      peer-asn: 64512
      my-asn: 64513
    address-pools:
    - name: default
      protocol: bgp
      addresses:
      - 192.168.1.200-192.168.1.255
EOF
    green "MetalLB configured."
}

# Step 6: Install MetalLB as the networking solution
install_metallb() {
    blue "Installing MetalLB for Kubernetes networking..."
    helm repo add metallb https://metallb.github.io/metallb
    helm repo update
    kubectl create namespace metallb-system
    helm install -n metallb-system metallb metallb/metallb -f $METALLB_CONFIG_DIR/metallb-values.yaml
    kubectl create configmap metallb --from-file=$METALLB_CONFIG_DIR/metallb-values.yaml
    kubectl apply -f $METALLB_CONFIG_DIR/metallb-values.yaml
    green "MetalLB installed and configs applied."
}

# Step 7: Install Longhorn for storage
install_longhorn() {
    blue "Installing Longhorn as a storage solution..."
    helm repo add longhorn https://charts.longhorn.io
    helm repo update
    helm install longhorn longhorn/longhorn \
        --namespace longhorn-system \
        --create-namespace \
        --version 1.6.2 \
        --set defaultSettings.defaultDataPath="/var/mnt/longhorn"
    green "Longhorn installed. Talos Kubernetes cluster setup is complete!"
}

# Step 8: Install and Run Theila UI for Talos in Docker
install_theila_docker() {
    blue "Running Theila UI for Talos in Docker..."

    # Run Theila as a Docker container
    docker run --rm \
        --volume $HOME/.talos/config:/opt/talosconfig:ro \
        --env TALOSCONFIG=/opt/talosconfig \
        --publish 8080:8080 \
        ghcr.io/siderolabs/theila \
        --address 0.0.0.0

    green "Theila UI is running in Docker on port 8080."
}

# Main function with Theila step added
main() {
    generate_talos_yaml_config
    generate_talos_config
    apply_talos_config
    bootstrap_talos_cluster
    configure_metallb
    install_metallb
    install_longhorn
    install_theila
}

# Execute the main function
main