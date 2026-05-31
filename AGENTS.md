# AGENTS

## Purpose

This repo manages the live Docker-based homelab:

- `cornwall` (`192.168.1.100`): Proxmox host and shared storage server
- `penzance` (`192.168.1.101`): Debian Docker VM

There is no active Kubernetes, Flux, or cluster deployment.

## Operating Rules

- Do not commit secrets, rendered secret files, pass-store contents, kubeconfigs, or private keys.
- Prefer `./scripts/homelab` over ad hoc commands when the CLI supports the operation.
- Treat `cornwall` and `penzance` as production-like hosts.
- Avoid destructive VM actions unless explicitly requested.
- When topology changes, update `homelab.yml`, render generated config, and update README/relevant docs together.

## Current Live Baseline

- `penzance` is the only Docker host in active use.
- Pi-hole is the source of truth for local DNS.
- Caddy on `penzance` provides local TLS for selected services.
- cloudflared exposes selected public ingress to Caddy.
- Portainer is installed for browser-based Docker management.

Do not reintroduce Kubernetes, worker nodes, monitoring, or heavy services without checking current hardware limits first.

## Required Paths

- inventory: [ansible/inventories/lab/hosts.yml](/Users/ryan/Projects/homelab/ansible/inventories/lab/hosts.yml)
- shared vars: [ansible/inventories/lab/group_vars/all.yml](/Users/ryan/Projects/homelab/ansible/inventories/lab/group_vars/all.yml)
- terraform vars: [terraform/terraform.tfvars](/Users/ryan/Projects/homelab/terraform/terraform.tfvars)
- source config: [homelab.yml](/Users/ryan/Projects/homelab/homelab.yml)
- CLI: [scripts/homelab](/Users/ryan/Projects/homelab/scripts/homelab)
- compose snippets: [compose-services](/Users/ryan/Projects/homelab/compose-services)
- README: [README.md](/Users/ryan/Projects/homelab/README.md)

## Standard Workflow

1. Inspect current repo state, `homelab.yml`, and the rendered inventory/group vars when debugging behavior.
2. Edit `homelab.yml` for intended topology/service changes.
3. Use `compose-services/` to find the Docker service snippet backing a container.
4. Run `./scripts/homelab config render`.
5. Use `./scripts/homelab plan` before changing VM lifecycle or services.
6. Apply only when the resulting Proxmox and Ansible actions are understood.
7. Run the smallest Ansible playbook needed:
   - `proxmox`
   - `penzance`
8. Verify live behavior after changes:
   - SSH reachability
   - Docker container status
   - service-level checks such as Pi-hole, Jellyfin, Isambard, or Portainer
9. Update docs when reality changed.

## CLI Reference

```sh
./scripts/homelab check-tools
./scripts/homelab config render
./scripts/homelab runtime restore --require-state
./scripts/homelab status
./scripts/homelab paths
./scripts/homelab ssh cornwall
./scripts/homelab ssh penzance
./scripts/homelab vms list
./scripts/homelab plan
./scripts/homelab apply --auto-approve
./scripts/homelab deploy ansible proxmox
./scripts/homelab deploy ansible penzance
```

## Runtime

Durable runtime material lives in the password store under `homelab/runtime`.
`/tmp/homelab` is only the materialized cache used by Terraform, Ansible, and SSH.

Runtime/generated cache files are intentionally untracked:

- `/tmp/homelab/ssh/`
- `/tmp/homelab/terraform-state/terraform.tfstate`
- `terraform/terraform.auto.tfvars.json`
- `ansible/inventories/lab/group_vars/all.secrets.yml`
- `.env.homelab`

## SSH Keys

SSH keys live under:

- password store: `homelab/runtime/ssh/`
- runtime cache: `/tmp/homelab/ssh/`

Expected active keys:

- `cornwall_root_ed25519`
- `penzance_automation_ed25519`
- `penzance_ryan_ed25519`

Use automation keys for tooling and `ryan` keys for manual access.
