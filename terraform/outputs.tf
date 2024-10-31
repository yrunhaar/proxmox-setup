# Capture control plane IPs
output "control_plane_ips" {
  value = [for vm in module.kubernetes_vms.control_plane : vm.ip_address]
}

# Capture worker IPs
output "worker_ips" {
  value = [for vm in module.kubernetes_vms.worker : vm.ip_address]
}