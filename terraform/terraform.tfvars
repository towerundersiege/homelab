# Generated from ../homelab.yml by ./scripts/homelab config render.
# Edit homelab.yml, not this file.

proxmox_endpoint                      = "https://192.168.1.100:8006/api2/json"
proxmox_username                      = "terraform@pve"
proxmox_insecure                      = true
cloudflare_enabled                    = true
cloudflare_manage_zone_rules          = false
cloudflare_manage_geo_restriction     = false
cloudflare_manage_cache_rule          = false
cloudflare_manage_rate_limit          = false
cloudflare_manage_warp_profile        = true
cloudflare_tunnel_manage_config       = true
cloudflare_public_hostnames           = ["jellyfin.towerundersiege.com", "navidrome.towerundersiege.com"]
cloudflare_private_network_cidrs      = ["192.168.1.0/24"]
cloudflare_private_dns_suffixes       = ["towerundersiege.com"]
cloudflare_private_dns_servers        = ["192.168.1.101"]
cloudflare_zero_trust_email_allowlist = ["info@towerundersiege.com"]
proxmox_node_name                     = "cornwall"
vm_template_id                        = 9000
vm_storage                            = "local-lvm"
cloud_init_storage                    = "local-lvm"
default_gateway                       = "192.168.1.254"
dns_servers                           = ["192.168.1.101", "1.1.1.1"]
ci_user                               = "ansible"
ci_password                           = null
vm_definitions = {
  penzance = {
    vm_id           = 100
    role            = "utility"
    ip_address      = "192.168.1.101"
    cidr            = 24
    cpu_cores       = 4
    memory_mb       = 16384
    disk_gb         = 48
    started         = true
    on_boot         = true
    tags            = ["terraform", "utility", "docker"]
    ssh_public_keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOBYMLaUpz08TKPKoGcRJX7gciqevrS1jkfaZt8gA4J7 ryan@penzance", "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJc48QnL63S/DOz1knXAOVfqr5Umj6tTkBrp8HCMj6al automation@penzance"]
  }
}
