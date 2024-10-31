# main.tf
terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "2.9.14"
    }
  }
}

provider "proxmox" {
  pm_api_url          = "https://${var.proxmox_server_ip}:8006/api2/json"
  pm_api_token_id     = var.proxmox_token_id
  pm_api_token_secret = var.proxmox_token_secret
  pm_tls_insecure     = true
}

# Importing network/base VMs (PfSense, Fedora, etc.)
module "network_vms" {
  source       = "./modules/network"
  vm_id_min    = 100
  vm_id_max    = 199
  additional_mac_address = var.additional_mac_address
  storage_pool = var.storage_pool
  target_node  = var.target_node
}

# Importing service VMs (Mattermost, GitLab, etc.)
module "service_vms" {
  source       = "./modules/service"
  vm_id_min    = 200
  vm_id_max    = 299
  storage_pool = var.storage_pool
  target_node  = var.target_node
}

# Importing Kubernetes VMs (Talos Control and Worker Nodes)
module "kubernetes_vms" {
  source         = "./modules/kubernetes"
  vm_id_min      = 300
  vm_id_max      = 399
  storage_pool   = var.storage_pool
  target_node    = var.target_node
  control_count  = 3
  worker_count   = 3
}

# Importing database VMs (PostgreSQL, MongoDB, etc.)
module "database_vms" {
  source       = "./modules/database"
  vm_id_min    = 400
  vm_id_max    = 499
  storage_pool = var.storage_pool
  target_node  = var.target_node
}