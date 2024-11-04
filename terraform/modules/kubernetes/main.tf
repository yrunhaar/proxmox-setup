# modules/kubernetes/main.tf
variable "vm_id_min" { type = number }
variable "vm_id_max" { type = number }
variable "storage_pool" { type = string }
variable "target_node" { type = string }
variable "talos_version" { type = string }

terraform {
  required_providers {
    proxmox = {
      source = "telmate/proxmox"
      version = "3.0.1-rc1"
    }
  }
}

# Dynamically create VMs.
module "compute_master" {
  source                   = "./compute-master"
  target_node              = var.target_node
  storage_pool             = var.storage_pool
  nodes                    = local.vm_master_nodes

  providers = {
    proxmox = proxmox
  }
}
module "compute_worker" {
  source                   = "./compute-worker"
  target_node              = var.target_node
  storage_pool             = var.storage_pool
  nodes                    = local.vm_worker_nodes

  providers = {
    proxmox = proxmox
  }
}

output "master_ips" {
  value = module.compute_master.ip_addresses
}

output "master_macs" {
  value = module.compute_master.mac_addrs
}

output "worker_ips" {
  value = module.compute_worker.ip_addresses
}

output "worker_macs" {
  value = module.compute_worker.mac_addrs
}