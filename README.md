# Homelab

This repo manages a small Docker-based homelab:

- `cornwall` (`192.168.1.100`): Proxmox host and shared storage server
- `penzance` (`192.168.1.101`): Debian VM running Docker Compose services

There is no active Kubernetes, Flux, or cluster deployment in this repo.

## Quick Start

The main commands are:

```sh
./scripts/homelab config render
./scripts/homelab runtime restore
./scripts/homelab status
./scripts/homelab ssh penzance
./scripts/homelab docker-update
./scripts/homelab plan
./scripts/homelab apply --auto-approve
```

`homelab.yml` is the source of truth. It defines the domain, network, Proxmox host, VMs, users, packages, services, and Cloudflare exposure. SSH key paths and public keys are derived from `homelab.ssh_key_dir` and host/user names. Service domains default to `<service-name>.<domain>` with underscores converted to hyphens, and can be overridden per service. Services are local by default, private to Cloudflare by default, and routed through Gluetun by default unless `gluetun: false` is set.

`config render` turns `homelab.yml` into Terraform vars, Ansible inventory, and shared Ansible vars. `plan` and `apply` restore the runtime cache, render config, and render secrets automatically before doing anything else. Terraform state and SSH keys live durably in `pass` under `homelab/runtime`; `/tmp/homelab` is only the local cache.

Docker services live as reusable snippets under `ansible/roles/docker_host/templates/compose-services/`, with a convenience symlink at [compose-services](./compose-services). A service in `homelab.yml` can opt into one with `compose_template: name.yml.j2`; service-specific knobs live under that service's `compose:` map.

## Using The CLI

`status` checks SSH reachability, Docker containers, Penzance-to-Cornwall connectivity, Pi-hole DNS answers, and local HTTPS endpoints.

`plan` renders runtime secrets, runs Terraform plan, and runs the Penzance Ansible playbook in check mode. Use `./scripts/homelab plan --diff` only when you specifically want Ansible diffs, because rendered templates can include sensitive values.

`apply` renders runtime secrets, applies Terraform, runs the Penzance playbook, then pulls and recreates the Docker Compose stack.

`docker-update` just pulls and recreates the Docker Compose stack on `penzance`.

`runtime restore` hydrates `/tmp/homelab` from `pass`.

`runtime import` seeds `pass` from the current cache, and `runtime save-state` refreshes only the Terraform state entry.

Use Terraform only when the VM definition changes:

```sh
./scripts/homelab deploy terraform-plan
./scripts/homelab deploy terraform-apply --auto-approve
```

Use the Proxmox playbook only when host storage or NFS changes:

```sh
./scripts/homelab deploy ansible proxmox
```

## Proxmox

The Proxmox host is `cornwall`.

VM lifecycle lives in Terraform. Host storage and NFS live in Ansible.

The current VM template ID comes from [homelab.yml](./homelab.yml). If you rebuild the template, update that file and rerender the generated Terraform vars.

## Services

`penzance` runs these containers:

- Pi-hole
- Jellyfin
- Navidrome
- Syncthing
- File Browser
- Isambard app
- Gluetun for the Isambard network path
- Caddy with Cloudflare DNS TLS
- cloudflared
- Portainer CE

Isambard uses floating GHCR tags:

- `ghcr.io/towerundersiege/isambard-app:latest`

## Browser Access

Local DNS is served by Pi-hole on `penzance`.

- `https://pihole.towerundersiege.com`
- `https://jellyfin.towerundersiege.com`
- `https://navidrome.towerundersiege.com`
- `https://syncthing.towerundersiege.com`
- `https://filebrowser.towerundersiege.com`
- `http://jellyfin-firetv.towerundersiege.com`
- `https://isambard.towerundersiege.com`
- `https://portainer.towerundersiege.com`

Public Cloudflare Tunnel ingress is configured for Jellyfin and Navidrome. Syncthing, File Browser, Isambard, and Portainer are intended for internal access through Pi-hole DNS.

Remote internal access uses Cloudflare Zero Trust/WARP private networking. Terraform manages the Cloudflare Tunnel private routes in `cloudflare_private_network_cidrs`, currently `192.168.1.0/24`, and configures WARP local domain fallback so `towerundersiege.com` resolves through Pi-hole while away from home.

### Firefox on macOS

If Firefox resolves a local hostname such as `isambard.towerundersiege.com` to `192.168.1.101` but cannot connect, check the macOS Local Network privacy permission:

`System Settings` -> `Privacy & Security` -> `Local Network` -> enable `Firefox`

This can look like a DNS or VPN issue even when Pi-hole, Mullvad custom DNS, and the service are all working. Brave or another browser may continue to work if it already has Local Network access.

If Firefox does not prompt or appears stuck, reset its local-network privacy entry and try the site again:

```sh
tccutil reset LocalNetwork org.mozilla.firefox
```

This permission is a macOS privacy control, not a normal Firefox profile setting. Nix-darwin can manage related system defaults and application installation, but do not assume it can pre-grant Firefox Local Network access.

## Storage

The DAS is attached to `cornwall`. Proxmox exports `/srv/storage/pool` over NFS, and `penzance` mounts it at `/srv/shared`. Shared content under `/srv/shared/media` and `/srv/shared/sync` is group-owned by `homelab` with setgid directories so manual edits and containers can cooperate without taking per-service ownership of the whole tree. Docker app config and service state stay on the `penzance` VM disk under `/var/lib/penzance` for lower-latency local storage.

Important paths:

- Proxmox pool: `/srv/storage/pool`
- App config/state on `penzance`: `/var/lib/penzance`
- Media library: `/srv/shared/media`
- Compose file on `penzance`: `/opt/penzance/docker-compose.yml`
- Local runtime cache: `/tmp/homelab`
- Terraform state cache: `/tmp/homelab/terraform-state/terraform.tfstate`

## Runtime

Durable runtime material lives in the password store under `homelab/runtime`. `/tmp/homelab` is only the materialized cache used by Terraform, Ansible, and SSH. If `/tmp` is cleared, hydrate it again with:

```sh
./scripts/homelab runtime restore --require-state
```

Terraform state is restored if it exists; if it has not been seeded yet, Terraform will start from a fresh local state on the next plan or apply.

To seed or refresh the password store from the current local cache:

```sh
./scripts/homelab runtime import
./scripts/homelab runtime save-state
```

Generated runtime cache files are local and ignored by Git:

- `terraform/terraform.auto.tfvars.json`
- `ansible/inventories/lab/group_vars/all.secrets.yml`
- `.env.homelab`
- `/tmp/homelab/ssh/`
- `/tmp/homelab/terraform-state/terraform.tfstate`

## SSH Keys

SSH keys are stored durably in `pass` under `homelab/runtime/ssh/` and restored into `/tmp/homelab/ssh`:

```text
/tmp/homelab/ssh/cornwall_root_ed25519
/tmp/homelab/ssh/penzance_automation_ed25519
/tmp/homelab/ssh/penzance_ryan_ed25519
```

The helper CLI uses the `ryan` identity by default for manual SSH and the automation key for Ansible.

```sh
./scripts/homelab ssh penzance
./scripts/homelab ssh --identity automation penzance -- sudo docker ps
```

To use plain OpenSSH without passing keys, print host entries with:

```sh
./scripts/homelab ssh-config
```

The `ryan` user is configured with passwordless sudo and Docker group membership.

## Layout

```text
.
├── compose-services -> ansible/roles/docker_host/templates/compose-services
├── ansible/
│   ├── inventories/lab/
│   ├── playbooks/
│   └── roles/
├── scripts/
├── terraform/
├── homelab.yml
└── README.md
```
