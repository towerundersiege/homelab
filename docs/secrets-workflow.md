# Secrets Workflow

This repository now expects operational secrets to live outside Git in a repo-local pass store, encrypted to a dedicated homelab GPG key.

## Why

- Terraform and Ansible both need secrets.
- The repo should stay self-contained operationally without keeping those secrets in tracked files.
- A dedicated GPG identity avoids mixing homelab infrastructure material with your normal personal keychain.

## Pass Store Layout

Recommended `pass` entries:

- `homelab/proxmox/password`
- `homelab/cloudflare/caddy_api_token`
- `homelab/cloudflare/tunnel_token`
- `homelab/pihole/web_password`
- `homelab/vault/root_token`
- `homelab/k3s/server_node_token`

Default local pass-store path:

- `.homelab-pass/`

Expected subtree inside that local store:

- `homelab/...`

## Bootstrap

Initialize the homelab GPG key and local pass store:

```sh
HOMELAB_GPG_PASSPHRASE='choose-a-strong-passphrase' ./scripts/init-homelab-pass.sh
```

Seed the required entries:

```sh
PASSWORD_STORE_DIR="$PWD/.homelab-pass" pass insert homelab/proxmox/password
PASSWORD_STORE_DIR="$PWD/.homelab-pass" pass insert homelab/cloudflare/caddy_api_token
PASSWORD_STORE_DIR="$PWD/.homelab-pass" pass insert homelab/cloudflare/tunnel_token
PASSWORD_STORE_DIR="$PWD/.homelab-pass" pass insert homelab/pihole/web_password
PASSWORD_STORE_DIR="$PWD/.homelab-pass" pass insert homelab/vault/root_token
PASSWORD_STORE_DIR="$PWD/.homelab-pass" pass insert homelab/k3s/server_node_token
```

## Rendering Runtime Secret Files

Render the untracked files used by Terraform, Ansible, and manual Compose:

```sh
./scripts/render-secrets.sh
```

That creates:

- `terraform/terraform.auto.tfvars.json`
- `ansible/inventories/lab/group_vars/all.secrets.yml`
- `.env.homelab`

All of those files are ignored by Git.

## Primary Entrypoint

Use the wrapper script for common operations. Deploy commands always render secrets first.

```sh
./scripts/homelab check-tools
./scripts/homelab ssh cornwall
./scripts/homelab vms ssh penzance
./scripts/homelab k8s kubeconfig lyonesse --sync
./scripts/homelab k8s kubectl lyonesse get nodes -o wide
./scripts/homelab deploy terraform-plan
./scripts/homelab deploy ansible proxmox
./scripts/homelab deploy ansible penzance
./scripts/homelab deploy ansible cluster
./scripts/homelab deploy all --auto-approve
```
