variable "proxmox_endpoint" {
  description = "Proxmox API endpoint, for example https://pve.lan:8006/api2/json"
  type        = string
}

variable "cloudflare_enabled" {
  description = "Enable Cloudflare-managed public edge resources for Jellyfin"
  type        = bool
  default     = false
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token used by Terraform for zone and tunnel management"
  type        = string
  sensitive   = true
  default     = ""
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID for Zero Trust tunnel management"
  type        = string
  default     = ""
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for towerundersiege.com"
  type        = string
  default     = ""
}

variable "cloudflare_tunnel_id" {
  description = "Existing remotely-managed Cloudflare Tunnel ID for penzance"
  type        = string
  default     = ""
}

variable "cloudflare_tunnel_manage_config" {
  description = "Whether Terraform should manage the full ingress list for the existing Cloudflare Tunnel"
  type        = bool
  default     = false
}

variable "cloudflare_manage_zone_rules" {
  description = "Whether Terraform should manage Cloudflare zone rulesets for Jellyfin"
  type        = bool
  default     = false
}

variable "cloudflare_manage_geo_restriction" {
  description = "Whether Terraform should manage the Jellyfin geo restriction rule"
  type        = bool
  default     = false
}

variable "cloudflare_manage_cache_rule" {
  description = "Whether Terraform should manage the Jellyfin cache bypass rule"
  type        = bool
  default     = false
}

variable "cloudflare_manage_rate_limit" {
  description = "Whether Terraform should manage the Jellyfin auth rate limit rule"
  type        = bool
  default     = false
}

variable "cloudflare_manage_warp_profile" {
  description = "Whether Terraform should manage WARP device profiles and local domain fallback"
  type        = bool
  default     = false
}

variable "cloudflare_zero_trust_email_allowlist" {
  description = "Email addresses allowed to access the homelab private network through Cloudflare Zero Trust"
  type        = list(string)
  default     = ["info@towerundersiege.com"]
}

variable "cloudflare_private_network_cidr" {
  description = "Private network CIDR routed through the Cloudflare Tunnel for homelab access"
  type        = string
  default     = "192.168.1.0/24"
}

variable "cloudflare_private_dns_suffixes" {
  description = "DNS suffixes that WARP should resolve via the homelab DNS server"
  type        = list(string)
  default     = ["towerundersiege.com"]
}

variable "cloudflare_private_dns_servers" {
  description = "DNS servers used for Zero Trust local domain fallback"
  type        = list(string)
  default     = ["192.168.1.101"]
}

variable "proxmox_username" {
  description = "Proxmox username, usually user@realm"
  type        = string
}

variable "proxmox_password" {
  description = "Proxmox password or API token secret if using password auth"
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Skip TLS verification for self-signed Proxmox certs"
  type        = bool
  default     = true
}

variable "proxmox_node_name" {
  description = "Target Proxmox node that hosts the VMs"
  type        = string
  default     = "pve"
}

variable "vm_template_id" {
  description = "VM ID of the Debian 12 cloud-init template in Proxmox"
  type        = number
}

variable "cloud_image_url" {
  description = "Source URL for the Debian cloud image used to build VMs"
  type        = string
  default     = "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2"
}

variable "cloud_image_datastore" {
  description = "Proxmox datastore used to store the downloaded cloud image import artifact"
  type        = string
  default     = "local"
}

variable "cloud_image_file_name" {
  description = "Filename for the downloaded Debian cloud image in Proxmox"
  type        = string
  default     = "debian-12-genericcloud-amd64.qcow2"
}

variable "vm_storage" {
  description = "Proxmox storage for VM disks"
  type        = string
  default     = "local-lvm"
}

variable "cloud_init_storage" {
  description = "Proxmox storage for cloud-init disk"
  type        = string
  default     = "local-lvm"
}

variable "default_gateway" {
  description = "Default gateway for guest networking"
  type        = string
}

variable "default_bridge" {
  description = "Bridge for guest networking"
  type        = string
  default     = "vmbr0"
}

variable "dns_servers" {
  description = "DNS servers for guest initialization"
  type        = list(string)
}

variable "ci_user" {
  description = "Cloud-init user to create on guests"
  type        = string
  default     = "ansible"
}

variable "ci_password" {
  description = "Optional cloud-init password"
  type        = string
  default     = null
  sensitive   = true
}

variable "vm_definitions" {
  description = "VM definitions keyed by hostname"
  type = map(object({
    vm_id           = number
    role            = string
    ip_address      = string
    cidr            = number
    cpu_cores       = number
    memory_mb       = number
    disk_gb         = number
    tags            = list(string)
    ssh_public_keys = list(string)
  }))
}
