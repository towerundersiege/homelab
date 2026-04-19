variable "proxmox_endpoint" {
  description = "Proxmox API endpoint, for example https://pve.lan:8006/api2/json"
  type        = string
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
