#!/bin/bash

# Color functions for output
red() { echo -e "\033[31m$1\033[0m"; }
green() { echo -e "\033[32m$1\033[0m"; }
blue() { echo -e "\033[34m$1\033[0m"; }

# Function to prompt for input with a default value
prompt_input() {
    local prompt=$1
    local default=$2
    read -p "$(blue "$prompt [$default]:") " input
    echo "${input:-$default}"
}

# Function to create bridge configuration for each additional IP
create_bridge_text() {
    local ip=$1
    local bridge_id=$2
    local mac_address=$3
    local external_bridge_id=$bridge_id
    local internal_bridge_id=$((bridge_id * 100))

    # WAN bridge configuration with MAC address and public IP
    local bridge_config="
auto vmbr${external_bridge_id}
iface vmbr${external_bridge_id} inet static
    address ${ip}
    netmask ${NETMASK}
    bridge_ports none
    bridge_stp off
    bridge_fd 0
    hwaddress ether ${mac_address}
#WAN ${external_bridge_id}
"

    # LAN bridge configuration without an IP, as it's for internal network only
    bridge_config+="
auto vmbr${internal_bridge_id}
iface vmbr${internal_bridge_id} inet manual
    bridge_ports none
    bridge_stp off
    bridge_fd 0
#LAN ${internal_bridge_id}
"
    echo "$bridge_config"
}

# Step 1: Collect network information
collect_network_info() {
    green "Collecting network configuration..."
    MAINSERVERIP=$(prompt_input "Main server IP" "192.168.0.1")
    GATEWAYADDRESS=$(prompt_input "Gateway address" "192.168.0.254")
    NETMASK=$(prompt_input "Netmask" "255.255.255.0")
    BROADCASTIP=$(prompt_input "Broadcast IP" "192.168.0.255")

    echo ""
    blue "Note: For Hetzner, ADDITIONAL_IP_ADDRESSES corresponds to the additional IPs listed under your server in the Hetzner Robot Console."
    blue "MAC_ADDRESSES correspond to the separate MAC addresses associated with each additional IP in the console."
    echo ""
    
    ADD_IP_ADDRESSES=$(prompt_input "Additional IPs (comma-separated)" "")
    MAC_ADDRESSES=$(prompt_input "MAC addresses for additional IPs (comma-separated)" "")
    NETWORK_INTERFACE=$(prompt_input "Network interface" "eth0")
}

# Step 2: Confirm configuration with the user
confirm_config() {
    green "You have entered the following configuration:"
    echo -e "Main server IP: $MAINSERVERIP\nGateway address: $GATEWAYADDRESS\nNetmask: $NETMASK\nBroadcast IP: $BROADCASTIP\nAdditional IPs: $ADD_IP_ADDRESSES\nMAC addresses: $MAC_ADDRESSES\nNetwork interface: $NETWORK_INTERFACE"
    read -p "$(blue "Is this correct? [yes/no]:") " confirmation
    [[ $confirmation != [Yy]* ]] && { red "Exiting without changes."; exit 1; }
}

# Step 3: Generate routing rules for additional IPs
generate_additional_routes() {
    additional_routes=""
    IFS=',' read -ra ADDR <<<"$ADD_IP_ADDRESSES"
    for add_ip in "${ADDR[@]}"; do
        additional_routes+="    up ip route add $add_ip dev ${NETWORK_INTERFACE}\n"
    done
}

# Step 4: Generate configuration for /etc/network/interfaces
generate_interface_content() {
    green "Generating network interface configuration..."
    interfaces_content="
### Hetzner Online GmbH installimage

source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback
iface lo inet6 loopback

iface ${NETWORK_INTERFACE} inet manual
    up ip route add -net ${GATEWAYADDRESS} netmask ${NETMASK} gw ${GATEWAYADDRESS} vmbr0
    up sysctl -w net.ipv4.ip_forward=1
    up sysctl -w net.ipv4.conf.${NETWORK_INTERFACE}.send_redirects=0
    up sysctl -w net.ipv6.conf.all.forwarding=1
$additional_routes
    up ip route add 192.168.0.0/16 via ${MAINSERVERIP} dev vmbr0
    up ip route add 172.16.0.0/12 via ${MAINSERVERIP} dev vmbr0
    up ip route add 10.0.0.0/8 via ${MAINSERVERIP} dev vmbr0

auto vmbr0
iface vmbr0 inet static
    address  ${MAINSERVERIP}
    netmask  ${NETMASK}
    gateway  ${GATEWAYADDRESS}
    broadcast  ${BROADCASTIP}
    bridge-ports ${NETWORK_INTERFACE}
    bridge-stp off
    bridge-fd 0
    pointopoint ${GATEWAYADDRESS}
#Main IP configuration
"
}

# Step 5: Add additional IP bridges to configuration
add_additional_bridges() {
    IFS=',' read -ra ADDR <<<"$ADD_IP_ADDRESSES"
    IFS=',' read -ra MACS <<<"$MAC_ADDRESSES"
    
    for i in "${!ADDR[@]}"; do
        bridge_id=$((i + 1))
        interfaces_content+=$(create_bridge_text "${ADDR[i]}" "$bridge_id" "${MACS[i]}")
    done
}

# Step 6: Apply the new configuration
apply_config() {
    green "Saving configuration to /etc/network/interfaces..."
    echo "$interfaces_content" > /tmp/new_interfaces
    timestamp=$(date +%Y%m%d-%H%M%S)
    mv /etc/network/interfaces /etc/network/interfaces.bak-$timestamp
    mv /tmp/new_interfaces /etc/network/interfaces
    green "Network configuration applied. Restart networking with: 'systemctl restart networking'"
}

# Execute steps
collect_network_info
confirm_config
generate_additional_routes
generate_interface_content
add_additional_bridges
apply_config