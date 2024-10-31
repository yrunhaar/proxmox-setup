# vars.tf
variable "proxmox_server_ip" {
  description = "Proxmox server IP address"
  type        = string
}

variable "proxmox_token_id" {
  description = "Proxmox API token ID"
  type        = string
}

variable "proxmox_token_secret" {
  description = "Proxmox API token secret"
  type        = string
}

variable "additional_mac_address" {
  description = "MAC address for the additional IP on Hetzner's network"
  type        = string
}

variable "storage_pool" {
  description = "Default storage pool for VMs"
  type        = string
  default     = "local"
}

variable "target_node" {
  description = "Target Proxmox node for VM deployment"
  type        = string
  default     = "pve"
}