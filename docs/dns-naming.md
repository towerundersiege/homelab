# DNS Naming Plan

This document proposes a local naming scheme under `towerundersiege.com` for Pi-hole-managed DNS records.

## Goals

- Keep names short and predictable.
- Separate physical hosts, utility VMs, cluster nodes, and service endpoints.
- Leave room for more Proxmox hosts, more utility VMs, and more Kubernetes nodes later.
- Avoid baking current pet names into the long-term infrastructure shape.

## Recommended Pattern

Use structured subdomains with real names, and keep the short pet names as optional aliases only.

### Hypervisors

- `cornwall.proxmox.towerundersiege.com` -> current Proxmox host

Future growth:

- `devon.proxmox.towerundersiege.com`
- `somerset.proxmox.towerundersiege.com`

### Utility / Infra VMs

- `penzance.vm.towerundersiege.com` -> current utility VM

### Kubernetes Node VMs

Kubernetes nodes are still VMs, so keep them under `vm`.

- `lyonesse-cp-01.vm.towerundersiege.com`
- `lyonesse-w-01.vm.towerundersiege.com`
- `lyonesse-w-02.vm.towerundersiege.com`

Future growth:

- `lyonesse-w-03.vm.towerundersiege.com`
- `avalon-cp-01.vm.towerundersiege.com`
- `avalon-w-01.vm.towerundersiege.com`
- `avalon-w-02.vm.towerundersiege.com`

### Cluster API and Shared Endpoints

- `api.lyonesse.k8s.towerundersiege.com` -> Kubernetes API endpoint or future control-plane VIP
- `ingress.lyonesse.k8s.towerundersiege.com` -> Cilium ingress/load balancer IP

### Human-Friendly Aliases

If you want to preserve the current pet names, make them aliases to the structured names:

- `cornwall.towerundersiege.com` -> `cornwall.proxmox.towerundersiege.com`
- `penzance.towerundersiege.com` -> `penzance.vm.towerundersiege.com`

That lets you keep memorable names without making them the primary infrastructure API.

## Initial Pi-hole Records

Suggested initial local records:

- `cornwall.proxmox.towerundersiege.com` -> `192.168.1.100`
- `cornwall.towerundersiege.com` -> `192.168.1.100`
- `penzance.vm.towerundersiege.com` -> `192.168.1.101`
- `penzance.towerundersiege.com` -> `192.168.1.101`
- `lyonesse-cp-01.vm.towerundersiege.com` -> `192.168.1.102`
- `lyonesse-w-01.vm.towerundersiege.com` -> `192.168.1.103`
- `lyonesse-w-02.vm.towerundersiege.com` -> `192.168.1.104`
- `api.lyonesse.k8s.towerundersiege.com` -> `192.168.1.102`
- `ingress.lyonesse.k8s.towerundersiege.com` -> `192.168.1.110`
- `pihole.towerundersiege.com` -> `192.168.1.110`
- `jellyfin.towerundersiege.com` -> `192.168.1.110`

## Notes

- Point service names like `pihole.towerundersiege.com` and `jellyfin.towerundersiege.com` at the ingress IP when they are exposed through a shared ingress layer.
- Keep infra names and service names separate. `cornwall.proxmox` is the hypervisor, `penzance.vm` is the VM, `api.lyonesse.k8s` is the cluster API, and `pihole.towerundersiege.com` is the application.
- Reserve the `k8s` subdomain for cluster-level identities, not individual nodes. Node machines remain under `vm`.
