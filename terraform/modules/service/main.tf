# modules/service/main.tf
variable "vm_id_min" { type = number }
variable "vm_id_max" { type = number }
variable "storage_pool" { type = string }
variable "target_node" { type = string }

# Define Mattermost VM
resource "proxmox_lxc" "mattermost" {
  vmid       = var.vm_id_min
  hostname   = "mattermost"
  ostemplate = "${var.storage_pool}:vztmpl/debian-12-turnkey-mattermost_18.0-1_amd64.tar.gz"
  target_node = var.target_node
  cores      = 2
  memory     = 4096
  rootfs     = "${var.storage_pool}:16G"
  network {
    name   = "eth0"
    bridge = "vmbr1"
    ip     = "dhcp"
  }
}