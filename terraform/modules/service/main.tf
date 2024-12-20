# modules/service/main.tf
variable "vm_id_min" { type = number }
variable "vm_id_max" { type = number }
variable "storage_pool" { type = string }
variable "target_node" { type = string }
variable "debian_ct_template" { type = string }
variable "mattermost_ct_template" { type = string }

terraform {
  required_providers {
    proxmox = {
      source = "telmate/proxmox"
      version = "3.0.1-rc1"
    }
  }
}

# Define Mattermost VM
resource "proxmox_lxc" "mattermost" {
  vmid       = var.vm_id_min
  hostname   = "mattermost"
  ostemplate = "${var.storage_pool}:vztmpl/${var.mattermost_ct_template}"
  target_node = var.target_node
  cores      = 2
  memory     = 4096
  rootfs {
    storage = var.storage_pool
    size    = "16G"
  }
  network {
    name   = "eth0"
    bridge = "vmbr1"
    ip     = "dhcp"
  }
  password = "password"
}

# Define Bytebase LXC
resource "proxmox_lxc" "bytebase" {
  vmid       = var.vm_id_min + 1  # Ensure unique VM ID
  hostname   = "bytebase"
  ostemplate = "${var.storage_pool}:vztmpl/${var.debian_ct_template}"
  target_node = var.target_node
  cores      = 2
  memory     = 2048
  rootfs {
    storage = var.storage_pool
    size    = "16G"
  }
  network {
    name   = "eth0"
    bridge = "vmbr1"
    ip     = "dhcp"  # Adjust to static IP if needed
  }
  password = "password"  # Replace with a secure password
}