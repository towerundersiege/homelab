terraform {
  required_version = ">= 1.7.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.8"
    }
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.63"
    }
  }
}
