packer {
  required_plugins {
    proxmox = {
      version = ">= 1.0.1"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

source "proxmox-iso" "talos" {
  proxmox_url              = var.proxmox_api_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  node                     = var.proxmox_node
  insecure_skip_tls_verify = true
  communicator             = "none"

  iso_file    = "${var.base_iso_file}"
  unmount_iso = true

  scsi_controller = "virtio-scsi-single"
  network_adapters {
    bridge = "vmbr1"
    model  = "e1000"
    firewall = true
  }
  disks {
    type              = "scsi"
    storage_pool      = var.proxmox_storage
    format            = "qcow2"
    disk_size         = "1500M"
    io_thread         = true
    cache_mode        = "writethrough"
  }

  memory               = 2048
  vm_id                = "9700"
  cores                = var.cores
  cpu_type             = var.cpu_type
  sockets              = "1"
  ssh_username         = "root"
  ssh_password         = "packer"
  ssh_timeout          = "15m"

  cloud_init              = true
  cloud_init_storage_pool = var.cloudinit_storage_pool

  template_name        = "talos-${var.talos_version}-cloud-init-template"
  template_description = "Talos ${var.talos_version} cloud-init, built on ${formatdate("YYYY-MM-DD hh:mm:ss ZZZ", timestamp())}"

  boot_wait = "25s"
  boot_command = [
    "<enter><wait1m>",
    "passwd<enter><wait>packer<enter><wait>packer<enter><wait15s>",
    "curl -s -L ${local.image} -o /tmp/talos.raw.xz<enter><wait2m>",
    "xz -d -c /tmp/talos.raw.xz | dd of=/dev/sda && sync<enter><wait2m>"
  ]
}

build {
  sources = ["source.proxmox-iso.talos"]
}
