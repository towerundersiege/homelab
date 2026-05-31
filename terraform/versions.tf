terraform {
  required_version = ">= 1.7.0"

  backend "local" {
    path = "/tmp/homelab/terraform-state/terraform.tfstate"
  }

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
