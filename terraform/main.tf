resource "proxmox_virtual_environment_vm" "vms" {
  for_each = var.vm_definitions

  node_name       = var.proxmox_node_name
  vm_id           = each.value.vm_id
  name            = each.key
  description     = local.default_description
  tags            = each.value.tags
  on_boot         = true
  stop_on_destroy = true

  cpu {
    cores = each.value.cpu_cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = each.value.memory_mb
    floating  = 0
  }

  agent {
    # The template does not provide a working guest agent on first boot yet.
    # Enabling agent waits here causes create to hang before state is written.
    enabled = false
  }

  disk {
    datastore_id = var.vm_storage
    import_from  = local.cloud_image_import_id
    interface    = "scsi0"
    size         = each.value.disk_gb
    discard      = "on"
    iothread     = true
    ssd          = true
  }

  initialization {
    datastore_id = var.cloud_init_storage

    dns {
      servers = var.dns_servers
    }

    ip_config {
      ipv4 {
        address = "${each.value.ip_address}/${each.value.cidr}"
        gateway = var.default_gateway
      }
    }

    user_account {
      username = var.ci_user
      password = var.ci_password
      keys     = each.value.ssh_public_keys
    }
  }

  network_device {
    bridge = var.default_bridge
    model  = "virtio"
  }

  operating_system {
    type = "l26"
  }

  serial_device {}

  boot_order = ["scsi0"]
}
