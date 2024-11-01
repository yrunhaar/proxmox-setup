# outputs.tf

# Capture master node IPs
output "master_ips" {
  value = [for vm in module.kubernetes_vms.compute_master : vm.ip_address]
}

# Capture master node MAC addresses
output "master_macs" {
  value = [for vm in module.kubernetes_vms.compute_master : vm.mac_addrs]
}

# Capture worker node IPs
output "worker_ips" {
  value = [for vm in module.kubernetes_vms.compute_worker : vm.ip_address]
}

# Capture worker node MAC addresses
output "worker_macs" {
  value = [for vm in module.kubernetes_vms.compute_worker : vm.mac_addrs]
}

# Talos Version Output
output "talos_version" {
  value = var.talos_version
}

# Talos Image ID Output
output "talos_disk_image_id"{
  value = var.talos_disk_image_id
}