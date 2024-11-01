# modules/network/main.tf

variable "vm_id_min" { type = number }
variable "vm_id_max" { type = number }
variable "storage_pool" { type = string }
variable "target_node" { type = string }
variable "fedora_iso_template" { type = string }

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
    file    = "${var.storage_pool}:iso/{var.fedora_iso_template}"
  }

  # Network interface
  network {
    model  = "virtio"
    bridge = "vmbr1"  # MAC will be generated automatically
    firewall = true
  }
}