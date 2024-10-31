# modules/network/main.tf

variable "vm_id_min" { type = number }
variable "vm_id_max" { type = number }
variable "storage_pool" { type = string }
variable "target_node" { type = string }
variable "additional_mac_address" { type = string }

# Define PfSense VM
resource "proxmox_vm_qemu" "pfsense" {
  vmid         = var.vm_id_min
  name         = "pfsense"
  memory       = 2048
  cores        = 2
  target_node  = var.target_node

  # Disk configuration
  disk {
    size    = "32G"
    storage = var.storage_pool
  }

  # Attach the PfSense ISO image
  cdrom {
    file    = "${var.storage_pool}:iso/netgate-installer-amd64.iso"
  }

  # Network interfaces
  network {
    model  = "e1000"
    bridge = "vmbr0"
    mac    = var.additional_mac_address  # MAC address variable for vmbr0
    firewall = true
  }

  network {
    model  = "e1000"
    bridge = "vmbr1"  # MAC will be generated automatically
    firewall = true
  }
}

# Define Fedora VM
resource "proxmox_vm_qemu" "fedora" {
  vmid         = var.vm_id_min + 1
  name         = "fedora"
  memory       = 4096
  cores        = 2
  target_node  = var.target_node

  # Disk configuration
  disk {
    size    = "32G"
    storage = var.storage_pool
  }

  # Attach the Fedora ISO image
  cdrom {
    file    = "${var.storage_pool}:iso/Fedora-Workstation-Live-x86_64-40-1.14.iso"
  }

  # Network interface
  network {
    model  = "virtio"
    bridge = "vmbr1"  # MAC will be generated automatically
    firewall = true
  }
}