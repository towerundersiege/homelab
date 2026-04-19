# AGENTS

## Purpose

This repo manages the live homelab on:

- `cornwall` (`192.168.1.100`) as the Proxmox host
- `penzance` (`192.168.1.101`) as the utility VM
- `lyonesse-cp-01` (`192.168.1.102`) as the single-node `k3s` cluster

Any agent working here should assume the repo is intended to reflect live infrastructure, not just an aspirational design.

## Operating Rules

- Do not commit secrets, rendered secret files, pass-store contents, kubeconfigs, or private keys.
- Do not replace the repo-local key/pass model with user-global paths.
- Prefer `./scripts/homelab` over ad hoc commands when the CLI already supports the operation.
- Treat `penzance` and `lyonesse-cp-01` as production-like hosts even if this is a homelab.
- Avoid destructive VM actions unless the user explicitly asks for them.
- When changing topology, update Terraform, Ansible inventory, README, and relevant docs together.

## Current Live Baseline

- `penzance` is the only Docker host in active use.
- `lyonesse` is intentionally single-node right now.
- Current active apps on the cluster are the lighter baseline only.
- Pi-hole is the source of truth for local DNS.
- `ExternalDNS` writes local DNS records into Pi-hole.
- Caddy on `penzance` provides local/public edge TLS for selected services.

Do not reintroduce worker nodes, monitoring, or heavy services into active deployment without checking current hardware limits first.

## Required Paths

- inventory: [ansible/inventories/lab/hosts.yml](/Users/ryan/Projects/k8s/ansible/inventories/lab/hosts.yml)
- shared vars: [ansible/inventories/lab/group_vars/all.yml](/Users/ryan/Projects/k8s/ansible/inventories/lab/group_vars/all.yml)
- terraform vars: [terraform/terraform.tfvars](/Users/ryan/Projects/k8s/terraform/terraform.tfvars)
- CLI: [homelab_cli.py](/Users/ryan/Projects/k8s/homelab_cli.py)
- wrapper: [scripts/homelab](/Users/ryan/Projects/k8s/scripts/homelab)
- secrets workflow: [docs/secrets-workflow.md](/Users/ryan/Projects/k8s/docs/secrets-workflow.md)

## Standard Workflow

1. Inspect current repo state and inventory.
2. Render secrets if Terraform/Ansible needs them.
3. Use `./scripts/homelab deploy terraform-plan` before changing VM lifecycle.
4. Apply Terraform only when the resulting Proxmox action is understood.
5. Run the smallest Ansible playbook needed:
   - `proxmox`
   - `penzance`
   - `cluster`
6. Verify live behavior after changes:
   - SSH reachability
   - cluster node readiness
   - Flux status
   - service-level checks such as Pi-hole or Jellyfin
7. Update docs when reality changed.

## CLI Reference

Preferred commands:

```sh
./scripts/homelab check-tools
./scripts/homelab ssh cornwall
./scripts/homelab ssh penzance
./scripts/homelab ssh lyonesse-cp-01
./scripts/homelab vms list
./scripts/homelab k8s list
./scripts/homelab k8s kubeconfig lyonesse --sync
./scripts/homelab k8s kubectl lyonesse get nodes -o wide
./scripts/homelab secrets list
./scripts/homelab deploy terraform-plan
./scripts/homelab deploy terraform-apply --auto-approve
./scripts/homelab deploy ansible penzance
./scripts/homelab deploy ansible cluster
```

## Secrets

Secrets live in the repo-local pass store:

- `.homelab-pass/`

Do not put secret values in:

- `README.md`
- `AGENTS.md`
- tracked Ansible vars
- tracked Terraform vars

Generated secret files are intentionally untracked:

- `terraform/terraform.auto.tfvars.json`
- `ansible/inventories/lab/group_vars/all.secrets.yml`
- `.env.homelab`

## SSH Keys

Repo-local SSH keys live under:

- `keys/ssh/`

Expected active keys:

- `cornwall_root_ed25519`
- `penzance_automation_ed25519`
- `penzance_ryan_ed25519`
- `lyonesse-cp-01_automation_ed25519`
- `lyonesse-cp-01_ryan_ed25519`

Use automation keys for tooling and `ryan` keys for manual access.

## Documentation Discipline

When the live setup changes, update at least:

- [README.md](/Users/ryan/Projects/k8s/README.md)
- [docs/penzance-inventory.md](/Users/ryan/Projects/k8s/docs/penzance-inventory.md) if `penzance` changes materially
- [docs/dns-naming.md](/Users/ryan/Projects/k8s/docs/dns-naming.md) if hostnames or exposure model change

Keep the README factual. It should describe what exists now, not a speculative future platform.
