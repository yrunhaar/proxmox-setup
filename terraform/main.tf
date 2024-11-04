# main.tf
terraform {
    required_version = ">= 0.13.0"
    required_providers {
        proxmox = {
            source = "telmate/proxmox"
            version = "3.0.1-rc1"
        }
    }
}

provider "proxmox" {
  pm_api_url          = var.proxmox_api_url
  pm_api_token_id     = var.proxmox_api_token_id
  pm_api_token_secret = var.proxmox_api_token_secret
  pm_tls_insecure     = true
}

# Importing service VMs (Mattermost, GitLab, etc.)
module "service_vms" {
  source       = "./modules/service"
  vm_id_min    = 200
  vm_id_max    = 299
  storage_pool = var.storage_pool
  target_node  = var.target_node
  mattermost_ct_template = var.mattermost_ct_template

  providers = {
    proxmox = proxmox
  }
}

# Importing Kubernetes VMs (Talos Control and Worker Nodes)
module "kubernetes_vms" {
  source         = "./modules/kubernetes"
  vm_id_min      = 300
  vm_id_max      = 399
  talos_version = var.talos_version
  storage_pool   = var.storage_pool
  target_node    = var.target_node

  providers = {
    proxmox = proxmox
  }
}

# Importing database VMs (PostgreSQL, MongoDB, etc.)
module "database_vms" {
  source       = "./modules/database"
  vm_id_min    = 400
  vm_id_max    = 499
  storage_pool = var.storage_pool
  target_node  = var.target_node
  postgresql_ct_template = var.postgresql_ct_template

  providers = {
    proxmox = proxmox
  }
}
