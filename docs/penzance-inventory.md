# Penzance Target State

This document describes what `penzance` should look like in the rebuilt homelab design.

## Role

`penzance` is the utility VM that stays outside Kubernetes.

It exists for:

- Pi-hole
- Vault
- break-glass access when the cluster is unhealthy
- any small ad hoc Docker workloads that are intentionally kept outside the cluster

It should not be the place where most application workloads live. Those should move to the `lyonesse` cluster over time.

## VM Shape

Target VM characteristics:

- name: `penzance`
- DNS name: `penzance.vm.towerundersiege.com`
- IP: `192.168.1.101`
- OS: Debian
- CPU: `2` cores
- RAM: `2048 MB`
- root disk: `48G`
- network: static IP on the main LAN
- cloud-init bootstrap user: `ansible`
- interactive admin user: `ryan`

## Storage Model

`penzance` should not own physical storage directly.

The desired storage model is:

1. disks stay attached to the Proxmox host,
2. Proxmox pools them with `mergerfs`,
3. Proxmox exports the pool over NFS,
4. `penzance` mounts the shared export at `/srv/shared`,
5. `penzance` uses only its own namespace within that shared storage.

The relevant paths for `penzance` are:

- `/srv/shared/vm/penzance` for VM-owned config and state
- `/srv/shared/media` for shared media that may be consumed by both `penzance` and Kubernetes workloads

`penzance` should not use:

- a directly attached data disk
- guest-local `mergerfs`
- `/data/crimson`

## Penzance-Owned Data

The `penzance` namespace is:

```text
/srv/shared/vm/penzance/
├── config/
│   └── pihole/
├── downloads/
├── torrents/
└── usenet/
```

That namespace is for data owned by the utility VM itself.

It should not be reused by Kubernetes applications.

## Shared Media

Shared media lives outside the VM namespace:

```text
/srv/shared/media/
├── movies/
├── music/
└── tv/
```

This is the cross-host content area.

Rules:

- `penzance` may read or serve this media if needed.
- Kubernetes apps such as Jellyfin may also consume it.
- Application config and mutable app state should not be stored here.

## Services on Penzance

The target-state Docker stack on `penzance` is intentionally small:

- `pihole`

Current repo status:

- Compose target-state examples are present for `pihole`
- Jellyfin has been removed from the Compose side and is intended to run through Flux on Kubernetes

## DNS and HTTP

`penzance` is responsible for local DNS through Pi-hole.

Structured infrastructure names:

- `cornwall.proxmox.towerundersiege.com`
- `penzance.vm.towerundersiege.com`
- `lyonesse-cp-01.vm.towerundersiege.com`
- `lyonesse-w-01.vm.towerundersiege.com`
- `lyonesse-w-02.vm.towerundersiege.com`
- `api.lyonesse.k8s.towerundersiege.com`
- `ingress.lyonesse.k8s.towerundersiege.com`

User-facing local app names:

- `pihole.towerundersiege.com`
- `jellyfin.towerundersiege.com`
- `isambard.towerundersiege.com`
- `isambard-browser.towerundersiege.com`
- future app names such as `grafana.towerundersiege.com`, `gitea.towerundersiege.com`

Target behavior:

- Pi-hole serves local DNS records for infrastructure and local-only app names
- Cilium ingress terminates TLS for selected local app names on `192.168.1.110`
- `pihole.towerundersiege.com` routes through Cilium to the Pi-hole web port on `192.168.1.101:8080`
- Cloudflare Tunnel runs in Kubernetes for selected public services

## User Model

`penzance` should have:

- bootstrap automation user: `ansible`
- human admin user: `ryan`

The `ryan` user should have:

- host-specific SSH key
- `zsh`
- the slimmed-down shell config defined in the Ansible common role
- practical debugging tools installed

## Operational Constraints

`penzance` should remain lightweight and reliable.

That means:

- no direct dependency on the cluster for DNS
- no broad app sprawl on the VM
- no mixing of VM-specific config with cluster-owned PVC data
- no plaintext tracked secrets in repo-managed Compose files

## Relationship to Kubernetes

`penzance` and `lyonesse` have different ownership boundaries:

- `penzance` owns DNS, Vault, and utility-host concerns
- `lyonesse` owns cluster-hosted applications
- shared media is neutral and may be consumed by both
- cluster-specific writable application data belongs under `k8s/lyonesse/*`

## Desired End State

When the rebuild is complete, `penzance` should be:

- a small Debian VM
- recreated from Terraform
- configured by Ansible
- backed by NFS-mounted shared storage
- serving Pi-hole locally under `pihole.towerundersiege.com`
- no longer carrying the historical single-VM application sprawl from the old setup
