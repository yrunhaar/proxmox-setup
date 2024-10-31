# modules/kubernetes/main.tf
variable "vm_id_min" { type = number }
variable "vm_id_max" { type = number }
variable "storage_pool" { type = string }
variable "target_node" { type = string }
variable "control_count" { type = number }
variable "worker_count" { type = number }

# Define Kubernetes Control Plane Nodes
resource "proxmox_vm_qemu" "k8s_control_plane" {
  count        = var.control_count
  vmid         = var.vm_id_min + count.index
  name         = "k8s-control-plane-${count.index}"
  memory       = 2048
  cores        = 2
  target_node  = var.target_node
  network {
    bridge = "vmbr1"
  }
  disk {
    size    = "32G"
    storage = var.storage_pool
  }
}

# Define Kubernetes Worker Nodes
resource "proxmox_vm_qemu" "k8s_worker" {
  count        = var.worker_count
  vmid         = var.vm_id_min + var.control_count + count.index
  name         = "k8s-worker-${count.index}"
  memory       = 2048
  cores        = 4
  target_node  = var.target_node
  network {
    bridge = "vmbr1"
  }
  disk {
    size    = "32"
    storage = var.storage_pool
  }
}