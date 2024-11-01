variable "proxmox_api_token_id" {
  type = string
}

variable "proxmox_api_token_secret" {
  type = string
}

variable "proxmox_api_url" {
  type = string
}

variable "proxmox_node" {
  type = string
}

variable "proxmox_storage" {
  type = string
}

variable "cpu_type" {
  type    = string
  default = "host"
}

variable "cores" {
  type    = string
  default = "2"
}

variable "cloudinit_storage_pool" {
  type    = string
  default = "local"
}

variable "base_iso_file" {
  type    = string
}

variable "talos_version" {
  type    = string
  default = "v1.8.2"
}

variable "talos_disk_image_id" {
  type    = string
}

locals {
  image = "https://factory.talos.dev/image/${var.talos_disk_image_id}/${var.talos_version}/nocloud-amd64.raw.xz"
}
