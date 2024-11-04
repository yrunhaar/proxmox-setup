# Capture master node IPs
output "master_vmids" {
  value = module.kubernetes_vms.master_vmids
}


# Capture master node MAC addresses
output "master_macaddrs" {
  value = module.kubernetes_vms.master_macaddrs
}

# Capture worker node IPs
output "worker_vmids" {
  value = module.kubernetes_vms.worker_vmids
}

# Capture worker node MAC addresses
output "worker_macaddrs" {
  value = module.kubernetes_vms.worker_macaddrs
}

# Talos Version Output
output "talos_version" {
  value = var.talos_version
}

# Talos Image ID Output
output "talos_disk_image_id"{
  value = var.talos_disk_image_id
}