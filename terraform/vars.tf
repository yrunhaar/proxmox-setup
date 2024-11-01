# vars.tf
variable "proxmox_api_url" {
  description = "Proxmox API url address"
  type        = string
}

variable "proxmox_api_token_id" {
  description = "Proxmox API token ID"
  type        = string
}

variable "proxmox_api_token_secret" {
  description = "Proxmox API token secret"
  type        = string
}

variable "target_node" {
  description = "Target Proxmox node for VM deployment"
  type        = string
  default     = "pve"
}

variable "storage_pool" {
  description = "Default storage pool for VMs"
  type        = string
  default     = "local"
}

variable "talos_version" {
  description = "Talos version for target clone of packer vm"
  type        = string
}

variable "talos_disk_image_id" {
  type    = string
}

# VM/CT Templates
variable "mattermost_ct_template" {
  description = "Mattermost CT Template ID"
  type        = string
}

variable "postgresql_ct_template" {
  description = "PostgreSQL CT Template ID"
  type        = string
}

variable "pfsense_iso_template" {
  description = "PfSense ISO Template ID"
  type        = string
}

variable "fedora_iso_template" {
  description = "Fedora ISO Template ID"
  type        = string
}

variable "ubuntu_server_iso_template" {
  description = "Ubuntu Server ISO Template ID"
  type        = string
}

