locals {
  # Master Node configuration
  vm_master_nodes = {
    "0" = {
      vm_id          = var.vm_id_min
      node_name      = "talos-master-00"
      clone_target   = "talos-${var.talos_version}-cloud-init-template"
      node_cpu_cores = "2"
      node_memory    = 2048
      node_disk      = "16" # in GB
    }
    "1" = {
      vm_id          = var.vm_id_min + 1
      node_name      = "talos-master-01"
      clone_target   = "talos-${var.talos_version}-cloud-init-template"
      node_cpu_cores = "2"
      node_memory    = 2048
      node_disk      = "16" # in GB
    }
    "2" = {
      vm_id          = var.vm_id_min + 2
      node_name      = "talos-master-02"
      clone_target   = "talos-${var.talos_version}-cloud-init-template"
      node_cpu_cores = "2"
      node_memory    = 2048
      node_disk      = "16" # in GB
    }
  }
  # Worker Node configuration
  vm_worker_nodes = {
    "0" = {
      vm_id                = var.vm_id_min + 10
      node_name            = "talos-worker-00"
      clone_target         = "talos-${var.talos_version}-cloud-init-template"
      node_cpu_cores       = "4"
      node_memory          = 6144
      node_disk            = "16"
      additional_node_disk = "32" # for longhorn
    }
    "1" = {
      vm_id                = var.vm_id_min + 11
      node_name            = "talos-worker-01"
      clone_target         = "talos-${var.talos_version}-cloud-init-template"
      node_cpu_cores       = "4"
      node_memory          = 6144
      node_disk            = "16"
      additional_node_disk = "32" # for longhorn
    }
    "2" = {
      vm_id                = var.vm_id_min + 12
      node_name            = "talos-worker-02"
      clone_target         = "talos-${var.talos_version}-cloud-init-template"
      node_cpu_cores       = "4"
      node_memory          = 6144
      node_disk            = "16"
      additional_node_disk = "32" # for longhorn
    }
  }
}
