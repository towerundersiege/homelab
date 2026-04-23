# Homelab Platform

This repo manages the current `towerundersiege.com` homelab running on one Proxmox host and two active VMs:

- `cornwall.proxmox.towerundersiege.com` (`192.168.1.100`): the Proxmox host
- `penzance.vm.towerundersiege.com` (`192.168.1.101`): Debian utility VM
- `lyonesse-cp-01.vm.towerundersiege.com` (`192.168.1.102`): single-node `k3s` cluster control plane

The cluster name is `lyonesse`. Right now it is intentionally a single-node cluster on the upgraded 32 GB Proxmox host.

## Current State

- Proxmox host storage is pooled on `cornwall` with `mergerfs` and exported over NFS.
- `penzance` mounts the shared storage at `/srv/shared`.
- Shared storage is split into:
  - `/srv/shared/vm/penzance`
  - `/srv/shared/media`
  - `/srv/shared/k8s/lyonesse`
- `penzance` runs:
  - Pi-hole
- `lyonesse` runs:
  - `k3s`
  - `Cilium`
  - `Flux`
  - `cert-manager`
  - `ExternalDNS` for Pi-hole
  - `external-secrets`
  - `nfs-subdir-external-provisioner`
  - Jellyfin
  - Isambard

## Topology

### Proxmox

- Host: `cornwall`
- IP: `192.168.1.100`
- API endpoint: `https://192.168.1.100:8006/api2/json`
- Node storage in use:
  - `local`
  - `local-lvm`
- Debian cloud-init template ID:
  - `9000`

### Utility VM

`penzance` is the utility edge VM and break-glass box.

- VMID: `100`
- IP: `192.168.1.101`
- CPU: `2`
- Memory: `1024 MB`
- Disk: `48 GB`
- OS user for automation: `ansible`
- Human user: `ryan`

It owns VM-specific state under:

- `/srv/shared/vm/penzance/config/pihole`

### Kubernetes

`lyonesse` is the current cluster.

- Cluster name: `lyonesse`
- API endpoint: `api.lyonesse.k8s.towerundersiege.com`
- API IP: `192.168.1.102`
- Ingress IP: `192.168.1.110`

Current node list:

- `lyonesse-cp-01`
  - VMID: `111`
  - IP: `192.168.1.102`
  - CPU: `2`
  - Memory: `8192 MB`
  - Disk: `48 GB`

The old worker definitions were removed from the active configuration. The repo currently models a single-node cluster on purpose.

## DNS and Exposure

Local DNS is handled by Pi-hole on `penzance`.

Important local records:

- `cornwall.proxmox.towerundersiege.com` -> `192.168.1.100`
- `penzance.vm.towerundersiege.com` -> `192.168.1.101`
- `lyonesse-cp-01.vm.towerundersiege.com` -> `192.168.1.102`
- `api.lyonesse.k8s.towerundersiege.com` -> `192.168.1.102`
- `ingress.lyonesse.k8s.towerundersiege.com` -> `192.168.1.110`
- `pihole.towerundersiege.com` -> `192.168.1.110`
- `jellyfin.towerundersiege.com` -> `192.168.1.110`
- `isambard.towerundersiege.com` -> `192.168.1.110`
- `isambard-browser.towerundersiege.com` -> `192.168.1.110`

Exposure model:

- `pihole.towerundersiege.com`
  - local DNS points to the Cilium ingress IP, `192.168.1.110`
  - Cilium terminates TLS with the cert-manager-managed `pihole-tls` secret
  - Cilium forwards to the Pi-hole web port on `penzance` at `192.168.1.101:8080`
  - direct break-glass access remains available at `http://192.168.1.101:8080`
- `jellyfin.towerundersiege.com`
  - local DNS points to the Cilium ingress IP, `192.168.1.110`
  - TLS terminates in-cluster through Cilium using the cert-manager-managed `cilium-apps-tls` secret
- `isambard.towerundersiege.com` and `isambard-browser.towerundersiege.com`
  - local DNS points to the Cilium ingress IP, `192.168.1.110`
  - TLS terminates in-cluster through Cilium using the cert-manager-managed `cilium-apps-tls` secret
  - Isambard's VPN sidecar allows inbound app and browser ports for cluster ingress traffic

## Storage Layout

The DAS is attached to `cornwall`, not to a guest.

On the Proxmox host:

- disks mount under `/srv/disks/*`
- pooled storage root is `/srv/storage/pool`
- that pool is exported over NFS

Inside guests:

- NFS is mounted at `/srv/shared`

Shared namespaces:

- `vm/<name>`: VM-owned config and state
- `media`: cross-host media library
- `k8s/<cluster>`: cluster-owned PVC-backed data

For the current setup that means:

- `/srv/shared/vm/penzance`
- `/srv/shared/media`
- `/srv/shared/k8s/lyonesse`

## Automation Split

- Terraform:
  - creates and updates the Proxmox VMs
- Ansible:
  - configures Proxmox host storage and NFS
  - configures guest base packages, users, SSH, Docker, `k3s`, `Cilium`, and Flux bootstrap
- Flux:
  - manages ongoing cluster resources and apps

## Repo Layout

```text
.
├── ansible/
├── docs/
├── flux/
├── keys/
│   └── ssh/
├── kubeconfig/
├── scripts/
├── terraform/
├── homelab_cli.py
└── AGENTS.md
```

## Helper CLI

Primary entrypoint:

```sh
./scripts/homelab
```

Useful commands:

```sh
./scripts/homelab check-tools
./scripts/homelab paths
./scripts/homelab ssh cornwall
./scripts/homelab ssh penzance
./scripts/homelab ssh lyonesse-cp-01
./scripts/homelab vms list
./scripts/homelab vms get penzance
./scripts/homelab k8s list
./scripts/homelab k8s get lyonesse
./scripts/homelab k8s kubeconfig lyonesse --sync
./scripts/homelab k8s kubectl lyonesse get nodes -o wide
./scripts/homelab deploy terraform-plan
./scripts/homelab deploy terraform-apply --auto-approve
./scripts/homelab deploy ansible proxmox
./scripts/homelab deploy ansible penzance
./scripts/homelab deploy ansible cluster
./scripts/homelab deploy all --auto-approve
```

`deploy` commands render secrets first.

## Secrets and Passwords

Secrets are not stored in tracked files. They live in the repo-local `pass` store:

- store path: `.homelab-pass/`
- prefix: `homelab/`

Expected entries:

- `homelab/proxmox/password`
- `homelab/cloudflare/dns_api_token`
- `homelab/cloudflare/terraform_api_token`
- `homelab/cloudflare/account_id`
- `homelab/cloudflare/zone_id`
- `homelab/cloudflare/tunnel_id`
- `homelab/cloudflare/tunnel_token`
- `homelab/pihole/web_password`
- `homelab/vault/root_token`
- `homelab/k3s/server_node_token`
- `homelab/hosts/penzance/ryan_password`
- `homelab/hosts/lyonesse-cp-01/ryan_password`
- `homelab/ssh/penzance_ryan_ed25519/passphrase`
- `homelab/ssh/lyonesse-cp-01_ryan_ed25519/passphrase`

Rendered secret outputs:

- `terraform/terraform.auto.tfvars.json`
- `ansible/inventories/lab/group_vars/all.secrets.yml`
- `.env.homelab`

Those files are ignored by Git.

Initialize and render:

```sh
HOMELAB_GPG_PASSPHRASE='...' ./scripts/init-homelab-pass.sh
./scripts/render-secrets.sh
```

Or use:

```sh
./scripts/homelab secrets init
./scripts/homelab secrets render
./scripts/homelab secrets list
./scripts/homelab secrets get pihole/web_password --reveal
./scripts/homelab secrets set pihole/web_password 'ExampleValue'
```

## SSH Keys

SSH keys are repo-local under `keys/ssh/` and are ignored by Git.

Current key set:

- `cornwall_root_ed25519`
- `penzance_ryan_ed25519`
- `penzance_automation_ed25519`
- `lyonesse-cp-01_ryan_ed25519`
- `lyonesse-cp-01_automation_ed25519`

There are also older `lyonesse-w-*` keys still present locally from the earlier multi-node layout. They are not part of the active inventory anymore.

Usage model:

- `*_automation_ed25519`
  - used by Terraform, Ansible, and non-interactive repo automation
- `*_ryan_ed25519`
  - default identity for `./scripts/homelab ssh ...`
  - manual operator access as `ryan`
- `cornwall_root_ed25519`
  - root access to the Proxmox host

Wrapper examples:

```sh
./scripts/homelab ssh penzance
./scripts/homelab ssh lyonesse-cp-01
./scripts/homelab ssh --identity automation lyonesse-cp-01
```

## Terraform

Current active VM definitions in `terraform/terraform.tfvars`:

- `penzance`
- `lyonesse-cp-01`

Current desired sizing:

- `penzance`: `1024 MB`
- `lyonesse-cp-01`: `8192 MB`

Useful commands:

```sh
cd terraform
terraform init
terraform plan
terraform apply -auto-approve
```

Or:

```sh
./scripts/homelab deploy terraform-plan
./scripts/homelab deploy terraform-apply --auto-approve
```

## Ansible

Important playbooks:

- `playbooks/proxmox.yml`
- `playbooks/penzance.yml`
- `playbooks/cluster.yml`
- `playbooks/site.yml`

Typical usage:

```sh
cd ansible
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook playbooks/proxmox.yml
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook playbooks/penzance.yml
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook playbooks/cluster.yml
```

Or:

```sh
./scripts/homelab deploy ansible proxmox
./scripts/homelab deploy ansible penzance
./scripts/homelab deploy ansible cluster
```

## Flux

Flux is bootstrapped against:

- repo: `git@github.com:towerundersiege/homelab.git`
- branch: `main`
- cluster path: `./flux/clusters/homelab`

Current active cluster baseline includes:

- Cilium
- cert-manager
- Pi-hole-driven `ExternalDNS`
- `external-secrets`
- NFS provisioner
- Jellyfin
- Isambard

Dependency updates are managed by Renovate. The scheduled workflow runs on Saturday mornings and opens or automerges eligible non-major updates for Helm releases and container image tags.

Monitoring and other heavier app workloads are not part of the active baseline.

## Current Constraints

- `lyonesse` stays single-node for now, with `8192 MB` allocated after the host RAM upgrade.
- The cluster can become sluggish after forced VM power cycles; Cilium and app pods may need time to recover.
- Pi-hole on `penzance` is the local DNS dependency for the rest of the environment.

## Related Docs

- [docs/secrets-workflow.md](/Users/ryan/Projects/k8s/docs/secrets-workflow.md)
- [docs/proxmox-setup.md](/Users/ryan/Projects/k8s/docs/proxmox-setup.md)
- [docs/dns-naming.md](/Users/ryan/Projects/k8s/docs/dns-naming.md)
- [docs/penzance-inventory.md](/Users/ryan/Projects/k8s/docs/penzance-inventory.md)
