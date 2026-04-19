output "vm_ips" {
  description = "Map of VM names to IP addresses"
  value = {
    for name, vm in var.vm_definitions : name => vm.ip_address
  }
}

output "ansible_inventory_hint" {
  description = "Suggested inventory host/IP mapping"
  value = [
    for name, vm in var.vm_definitions : "${name} ansible_host=${vm.ip_address}"
  ]
}
