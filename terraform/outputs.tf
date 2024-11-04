# outputs.tf

# Capture master node IPs
output "master_ips" {
  value = module.kubernetes_vms.master_ips
}

# Capture master node MAC addresses
output "master_macs" {
  value = module.kubernetes_vms.master_macs
}

# Capture worker node IPs
output "worker_ips" {
  value = module.kubernetes_vms.worker_ips
}

# Capture worker node MAC addresses
output "worker_macs" {
  value = module.kubernetes_vms.worker_macs
}

# Talos Version Output
output "talos_version" {
  value = var.talos_version
}

# Talos Image ID Output
output "talos_disk_image_id"{
  value = var.talos_disk_image_id
}