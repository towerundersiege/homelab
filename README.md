# Homelab Platform

This repository bootstraps a small Proxmox-backed homelab around one Debian utility VM (`penzance`) and a three-node `k3s` cluster. The intended outcome is:

- `penzance`: Debian utility VM used for Pi-hole, Vault, and break-glass Docker workloads.
- `lyonesse-cp-01`: control-plane node VM for the `lyonesse` cluster.
- `lyonesse-w-01`: worker node VM for the `lyonesse` cluster.
- `lyonesse-w-02`: worker node VM for the `lyonesse` cluster.
- Shared storage on the Proxmox host backed by the DAS, pooled with `mergerfs` now and ready for `snapraid` later.
- `Flux` for GitOps delivery into the cluster.
- `Cilium` as the CNI and ingress/L2 load balancer.
- `cloudflared` for public exposure of selected services.
- Local-only ingress through the same `towerundersiege.com` zone, resolved internally by Pi-hole.
- `ExternalDNS` to sync selected Kubernetes ingress and service hostnames into Pi-hole.
- Platform services for metrics/logging, storage, secrets, and application workloads.

## Current Scope

This scaffold gives you:

- A written target architecture and operating assumptions.
- Terraform for four Proxmox VM resources.
- Ansible playbooks and roles to:
  - configure the Proxmox host storage pool and NFS export,
  - install Docker services on `penzance`,
  - bootstrap `k3s`,
  - install `Cilium`,
  - install `Flux`.
- A Python Click CLI under `scripts/homelab` for secrets, SSH access, local kubeconfig management, cluster access, and deployment workflows.
- A Flux repository structure for infrastructure and application Helm releases.

It does not yet give you a zero-touch production deployment. Some values are intentionally placeholders because they are environment-specific:

- Proxmox API endpoint and token.
- VM template IDs and storage names.
- LAN CIDRs, node IPs, and DNS addresses.
- Cloudflare tunnel credentials.
- Vault initialization and unseal strategy.
- Exact app storage sizes and media paths.

## Design Decisions

### 1. Debian first, NixOS later

You mentioned NixOS for the `k3s` nodes. That can work, but combining `Terraform + Ansible + NixOS + k3s + Cilium + Flux + Vault` introduces two separate host configuration models before the baseline cluster exists.

The scaffold here uses Debian 12 as the first implementation target for all four VMs. That is the shortest path to a working cluster. Once the platform is stable, the three `k3s` nodes can be rebuilt onto NixOS with either:

- Terraform unchanged and Ansible replaced for host config, or
- Terraform unchanged and Nix used only inside the node images.

### 2. `penzance` stays outside the cluster

`penzance` is kept as a conventional Debian/Docker utility host for:

- Pi-hole
- Vault
- ad hoc containers
- break-glass access when the cluster is unhealthy

That separation is deliberate. DNS and secrets remain available even if `k3s` is degraded.

### 3. Shared storage via Proxmox host + NFS

The DAS is attached to the Proxmox host, so the cleanest first implementation is:

1. mount individual disks on the Proxmox host,
2. pool them with `mergerfs`,
3. export a shared path over NFS,
4. mount that NFS export in `penzance` and in the `k3s` nodes,
5. use `nfs-subdir-external-provisioner` in Kubernetes for persistent volumes.

Later, when more disks are present, `snapraid` can be added on the Proxmox host without changing the cluster storage model.

This is also the preferred replacement for the current legacy setup where the 8 TB disk is attached directly to `penzance` and pooled inside the guest with `mergerfs`. The improved design is:

1. keep physical disks attached to the Proxmox host,
2. pool them once on the Proxmox host,
3. export the pool over NFS,
4. mount that export in guests,
5. separate utility-host config, shared media, and k8s PVC data into different namespaces.

That gives you one storage control plane instead of hiding the main data disk behind a single VM.

The storage split in this repository is now:

- `vm/penzance/*` for utility-host-specific config and state
- `media/*` for cross-host media libraries
- `k8s/lyonesse/*` for cluster-specific PVC-backed application data

That avoids multiple hosts writing into the same application config tree while still allowing both `penzance` and `k8s` workloads to consume the same media library.

### 4. GitOps split

- Terraform: VM lifecycle on Proxmox.
- Ansible: base OS, storage wiring, Docker host config, `k3s`, `Cilium`, Flux bootstrap.
- Flux: all ongoing cluster resources and apps.

## Hardware Constraints

The current host has 8 GB RAM total. That is the main practical limitation here.

Running all of the following together on one box is possible only with tight sizing and low expectations:

- Proxmox
- one Debian utility VM
- three `k3s` VMs
- Pi-hole
- Vault
- Grafana
- Loki
- Gitea
- Jellyfin
- Vaultwarden
- Syncthing

Recommended minimum for this design is 16 GB RAM, and 32 GB would be materially better. The sample Terraform sizing in this repo is conservative, but you should treat observability and Jellyfin as optional until memory pressure is validated.

## Target Topology

### Proxmox host

- mounts DAS disks under `/srv/disks/*`
- pools them under `/srv/storage/pool`
- exports `/srv/storage/pool` as NFS

### Utility VM: `penzance`

- Debian 12
- Docker Engine + Compose plugin
- Pi-hole
- HashiCorp Vault
- optional future ad hoc containers
- mounts shared NFS storage at `/srv/shared`
- keeps its own config/state under `/srv/shared/vm/penzance`

### Kubernetes VMs

- Debian 12
- `k3s`
- `flannel` disabled
- `servicelb` disabled
- `traefik` disabled
- `Cilium` installed after cluster bootstrap
- shared NFS mounted at `/srv/shared`

### In-cluster services

- `external-secrets` wired to Vault
- `external-dns` wired to Pi-hole for local DNS automation
- `nfs-subdir-external-provisioner`
- `kube-prometheus-stack`
- `loki`
- `cloudflared`
- `gitea`
- `vaultwarden`
- `syncthing`
- `jellyfin`
- `gluetun` pattern placeholder for VPN-routed workloads

## DNS and Ingress Model

### Public apps

Selected apps should be exposed through Cloudflare Tunnel:

- public DNS in Cloudflare
- `cloudflared` running in the cluster
- origin services exposed internally via Kubernetes service/ingress

### Local-only apps

Local-only apps should resolve from Pi-hole using the same zone:

- `grafana.towerundersiege.com`
- `gitea.towerundersiege.com`
- `jellyfin.towerundersiege.com`
- etc.

Internally, those records should point at the Cilium ingress/load balancer IP on the LAN.

## Repository Layout

```text
.
├── ansible/
├── flux/
└── terraform/
```

## Bootstrap Flow

1. Prepare a Debian 12 cloud-init template in Proxmox.
2. Apply Terraform to create or reconcile all four VMs.
3. Run the Proxmox-host Ansible playbook to configure `mergerfs` and NFS.
4. Run the VM Ansible playbooks to:
   - install Docker on `penzance`,
   - mount shared storage,
   - install Pi-hole and Vault,
   - bootstrap `k3s`,
   - install `Cilium`,
   - install Flux.
5. Push this repo to Git and point Flux at it.
6. Let Flux reconcile infrastructure and apps.

## Terraform Notes

The original intent was to import the existing `penzance` VM. In practice, the current `bpg/proxmox` provider import path proved unreliable in this environment. The safer operating assumption for this repository is therefore:

1. inventory the old VM first,
2. migrate storage deliberately,
3. recreate `penzance` from the template when ready,
4. restore only the services that should remain outside the cluster.

That is why the repository now models the improved end-state instead of the legacy direct-disk guest layout.

## Ansible Notes

- Inventory is static to start with.
- Secrets are rendered into the untracked file `ansible/inventories/lab/group_vars/all.secrets.yml`.
- The roles are intentionally explicit and small rather than heavily abstracted.

## Secrets Notes

This repository now assumes secrets are managed via a dedicated homelab `pass` store encrypted to a dedicated homelab GPG key. See [docs/secrets-workflow.md](/Users/ryan/Projects/k8s/docs/secrets-workflow.md).

## Flux Notes

The Flux manifests are scaffolded, but actual bootstrap still requires:

- a Git remote,
- a repository URL,
- credentials,
- Vault secret paths and roles,
- Cloudflare tunnel secret material.

## Known Gaps

- Vault auto-unseal is not configured yet.
- `Obsidian` is not represented as a concrete app manifest because there is no canonical self-hosted Obsidian server; decide whether you want LiveSync, CouchDB, or another sync-compatible service.
- Backup, disaster recovery, and media transcoding tuning are not implemented yet.
- `gluetun` is included as a deployment pattern placeholder, not yet integrated with a specific workload.
- The current hardware is RAM-constrained. Until the memory upgrade lands, treat `lyonesse` as an effectively 2-node cluster.

## Suggested Next Steps

1. Fill out `terraform/terraform.tfvars`.
2. Decide the static IPs for all four VMs.
3. Create or verify the Debian cloud-init template in Proxmox.
4. Initialize the homelab pass store and seed the required secret entries.
5. Sync a local kubeconfig when needed with `./scripts/homelab k8s kubeconfig lyonesse --sync`.
6. Use `./scripts/homelab ssh cornwall` and `./scripts/homelab vms ssh <name>` for access through the repo-local keys.
7. Use `./scripts/homelab deploy all --auto-approve` for the full render/init/plan/apply/ansible flow.
