proxmox_endpoint = "https://192.168.1.100:8006/api2/json"
proxmox_username = "terraform@pve"
proxmox_insecure = true

proxmox_node_name  = "cornwall"
vm_template_id     = 9000
vm_storage         = "local-lvm"
cloud_init_storage = "local-lvm"

default_gateway = "192.168.1.254"
dns_servers     = ["192.168.1.101", "1.1.1.1"]

ci_user     = "ansible"
ci_password = null

vm_definitions = {
  penzance = {
    vm_id      = 100
    role       = "utility"
    ip_address = "192.168.1.101"
    cidr       = 24
    cpu_cores  = 2
    memory_mb  = 1024
    disk_gb    = 48
    tags       = ["terraform", "utility", "docker"]
    ssh_public_keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOBYMLaUpz08TKPKoGcRJX7gciqevrS1jkfaZt8gA4J7 ryan@penzance",
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJc48QnL63S/DOz1knXAOVfqr5Umj6tTkBrp8HCMj6al automation@penzance",
    ]
  }
  lyonesse-cp-01 = {
    vm_id      = 111
    role       = "k3s-control-plane"
    ip_address = "192.168.1.102"
    cidr       = 24
    cpu_cores  = 2
    memory_mb  = 8192
    disk_gb    = 48
    tags       = ["terraform", "k3s", "control-plane"]
    ssh_public_keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPd7xW7LPfnZpRWqHIXYDoxdZkzwD0QxA0Uhj6Ttgu5X ryan@lyonesse-cp-01",
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOA1T2ekAkm6nSv/JV5avu1fKyf7U6vHnJ8CWp0cK9Pq automation@lyonesse-cp-01",
    ]
  }
}
