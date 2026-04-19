# Proxmox Setup

This document records the one-time Proxmox setup commands for this repository.

## Terraform Service Account

Use a dedicated Proxmox user and API token for Terraform instead of `root@pam`.

Run these commands on the Proxmox host:

```sh
pveum user add terraform@pve -comment "Terraform service account"
pveum passwd terraform@pve

pveum role add TerraformProv --privs "VM.Allocate VM.Clone VM.Config.CDROM VM.Config.CPU VM.Config.Cloudinit VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate VM.PowerMgmt Datastore.AllocateSpace Datastore.Audit SDN.Use Sys.Audit"

pveum acl modify / -user terraform@pve -role TerraformProv

pveum user token add terraform@pve provider --privsep 0
```

Notes:

- `VM.Monitor` is not a valid Proxmox privilege and should not be included.
- The API token command prints the token secret once. Save it immediately.
- For the current Terraform provider configuration in this repo, use:
  - username: `terraform@pve!provider`
  - password: the token secret shown by `pveum user token add`

## Simpler Alternative

If you do not want to maintain a custom role yet, you can start broader and tighten later:

```sh
pveum user add terraform@pve -comment "Terraform service account"
pveum passwd terraform@pve
pveum acl modify / -user terraform@pve -role PVEAdmin
pveum user token add terraform@pve provider --privsep 0
```

That grants more access than Terraform strictly needs, but it is simpler for initial bootstrap.

## Upload the Cornwall Root SSH Key

From your local machine, upload the dedicated Cornwall root key with:

```sh
ssh-copy-id -i ./keys/ssh/cornwall_root_ed25519.pub root@192.168.1.100
```

If `ssh-copy-id` is not available, use:

```sh
cat ./keys/ssh/cornwall_root_ed25519.pub | ssh root@192.168.1.100 "umask 077; mkdir -p /root/.ssh && cat >> /root/.ssh/authorized_keys"
```

## Find the Debian Cloud-Init Template ID

SSH to the Proxmox host:

```sh
ssh -i ./keys/ssh/cornwall_root_ed25519 root@192.168.1.100
```

List all QEMU VMs and templates:

```sh
qm list
```

Check whether a specific VM ID is a template:

```sh
qm config <vmid> | grep '^template:'
```

A VM is a template if that command returns:

```text
template: 1
```

To list all VM IDs that are templates:

```sh
for id in $(qm list | awk 'NR>1 {print $1}'); do
  if qm config "$id" | grep -q '^template: 1'; then
    echo "$id"
  fi
done
```

To show template IDs with names:

```sh
for id in $(qm list | awk 'NR>1 {print $1}'); do
  if qm config "$id" | grep -q '^template: 1'; then
    name=$(qm config "$id" | awk '/^name:/ {print $2}')
    echo "$id $name"
  fi
done
```

## Create a Debian 12 Cloud-Init Template

If you do not already have a Debian template, this is a working baseline:

```sh
wget https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2 -O /var/lib/vz/template/qemu/debian-12-genericcloud-amd64.qcow2
qm create 9000 --name debian-12-cloudinit --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0
qm importdisk 9000 /var/lib/vz/template/qemu/debian-12-genericcloud-amd64.qcow2 local-lvm
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0
qm set 9000 --ide2 local-lvm:cloudinit
qm set 9000 --boot order=scsi0
qm set 9000 --serial0 socket --vga serial0
qm template 9000
```

This repository currently assumes template ID `9000`.

## If `qm create 9000` Says the VM Already Exists

That means VM ID `9000` is already in use. Check what it is:

```sh
qm list | grep '^9000 '
qm config 9000
```

If VM `9000` is already the template you want, verify it:

```sh
qm config 9000 | grep '^template:'
```

If the output is:

```text
template: 1
```

then you can keep using `9000` in Terraform.

If `9000` exists but is not the right template, pick another unused VM ID, for example `9001`, and use:

```sh
wget https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2 -O /var/lib/vz/template/qemu/debian-12-genericcloud-amd64.qcow2
qm create 9001 --name debian-12-cloudinit --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0
qm importdisk 9001 /var/lib/vz/template/qemu/debian-12-genericcloud-amd64.qcow2 local-lvm
qm set 9001 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9001-disk-0
qm set 9001 --ide2 local-lvm:cloudinit
qm set 9001 --boot order=scsi0
qm set 9001 --serial0 socket --vga serial0
qm template 9001
```

Then update `vm_template_id` in `terraform/terraform.tfvars`.

## Reference

The privilege names and `pveum` examples were checked against the official Proxmox documentation:

- https://pve.proxmox.com/pve-docs/chapter-pveum.html
- https://pve.proxmox.com/pve-docs/pveum.1.html
