locals {
  # Master Node configuration
  vm_master_nodes = {
    "0" = {
      vm_id          = 300
      node_name      = "talos-master-00"
      clone_target   = "talos-v1.8.2-cloud-init-template"
      node_cpu_cores = "2"
      node_memory    = 2048
      node_disk      = "32" # in GB
    }
    "1" = {
      vm_id          = 301
      node_name      = "talos-master-01"
      clone_target   = "talos-v1.8.2-cloud-init-template"
      node_cpu_cores = "2"
      node_memory    = 2048
      node_disk      = "32" # in GB
    }
    "2" = {
      vm_id          = 302
      node_name      = "talos-master-02"
      clone_target   = "talos-v1.8.2-cloud-init-template"
      node_cpu_cores = "2"
      node_memory    = 2048
      node_disk      = "32" # in GB
    }
  }
  # Worker Node configuration
  vm_worker_nodes = {
    "0" = {
      vm_id                = 310
      node_name            = "talos-worker-00"
      clone_target         = "talos-v1.8.2-cloud-init-template"
      node_cpu_cores       = "4"
      node_memory          = 6144
      node_disk            = "32"
    }
    "1" = {
      vm_id                = 311
      node_name            = "talos-worker-01"
      clone_target         = "talos-v1.8.2-cloud-init-template"
      node_cpu_cores       = "4"
      node_memory          = 6144
      node_disk            = "32"
    }
    "2" = {
      vm_id                = 312
      node_name            = "talos-worker-02"
      clone_target         = "talos-v1.8.2-cloud-init-template"
      node_cpu_cores       = "4"
      node_memory          = 6144
      node_disk            = "32"
    }
  }
}
