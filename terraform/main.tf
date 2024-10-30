# terraform/main.tf

terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "2.9.14"
    }
  }
}

provider "proxmox" {
  pm_api_url          = "https://${var.pve_server_ip}:8006/api2/json"
  pm_api_token_id     = var.proxmox_token_id
  pm_api_token_secret = var.proxmox_token_secret
  pm_tls_insecure     = true
}

resource "proxmox_lxc" "containers" {
  for_each       = var.lxc_containers

  target_node    = var.target_node
  hostname       = each.key
  vmid           = each.value.vm_id
  ostemplate     = local.lxc_container_templates[each.value.template].ostemplate
  unprivileged   = true

  rootfs {
    storage = var.storage_pool
    size    = local.lxc_container_templates[each.value.template].disk
  }

  cores    = local.lxc_container_templates[each.value.template].cores
  memory   = local.lxc_container_templates[each.value.template].memory
  swap     = local.lxc_container_templates[each.value.template].swap

  network {
    name   = "eth0"
    bridge = "vmbr1"
    ip     = "dhcp"
  }

  ssh_public_keys = file(pathexpand("~/.ssh/id_rsa.pub"))

  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i '${self.network.ipv4.address},' -u root ansible/playbooks/setup-lxc-container.yml"
    environment = {
      CONTAINER_REGISTRY_TOKEN = var.container_registry_token
      DOCKER_IMAGE_PATH        = var.docker_image_path
    }
  }
}