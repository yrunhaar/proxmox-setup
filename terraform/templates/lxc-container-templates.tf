# terraform/templates/lxc-container-templates.tf

locals {
  lxc_container_templates = {
    "debian-1171-small" = {
      ostemplate = "local:vztmpl/debian-11-standard_11.7-1_amd64.tar.zst"
      cores      = 2
      memory     = 2048
      disk       = 16
      swap       = 512
    }
    "debian-1171-medium" = {
      ostemplate = "local:vztmpl/debian-11-standard_11.7-1_amd64.tar.zst"
      cores      = 4
      memory     = 4096
      disk       = 32
      swap       = 1024
    }
    "debian-1171-large" = {
      ostemplate = "local:vztmpl/debian-11-standard_11.7-1_amd64.tar.zst"
      cores      = 8
      memory     = 8192
      disk       = 64
      swap       = 2048
    }
    "debian-1271-small" = {
      ostemplate = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
      cores      = 2
      memory     = 2048
      disk       = 16
      swap       = 512
    }
    "debian-1271-medium" = {
      ostemplate = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
      cores      = 4
      memory     = 4096
      disk       = 32
      swap       = 1024
    }
    "debian-1271-large" = {
      ostemplate = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
      cores      = 8
      memory     = 8192
      disk       = 64
      swap       = 2048
    }
  }
}