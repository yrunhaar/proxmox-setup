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

variable "talos_version" {
  type    = string
  default = "v1.8.2"
}

variable "base_iso_file" {
  type    = string
}

locals {
  image = "https://factory.talos.dev/image/ce4c980550dd2ab1b17bbf2b08801c7eb59418eafe8f279833297925d67c7515/v1.8.2/nocloud-amd64.raw.xz"
}
