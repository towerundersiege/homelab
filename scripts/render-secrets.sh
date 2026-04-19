#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS_STORE_DIR="${HOMELAB_PASSWORD_STORE_DIR:-$ROOT_DIR/.homelab-pass}"
PASS_PREFIX="${HOMELAB_PASS_PREFIX:-homelab}"
export PASSWORD_STORE_DIR="$PASS_STORE_DIR"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing required command: $1" >&2
    exit 1
  }
}

pass_get() {
  pass show "$1" | head -n 1
}

require_cmd pass

mkdir -p "$ROOT_DIR/terraform"
mkdir -p "$ROOT_DIR/ansible/inventories/lab/group_vars"

proxmox_password="$(pass_get "$PASS_PREFIX/proxmox/password")"
caddy_cloudflare_api_token="$(pass_get "$PASS_PREFIX/cloudflare/caddy_api_token")"
cloudflared_tunnel_token="$(pass_get "$PASS_PREFIX/cloudflare/tunnel_token")"
pihole_web_password="$(pass_get "$PASS_PREFIX/pihole/web_password")"
vault_root_token="$(pass_get "$PASS_PREFIX/vault/root_token")"
k3s_server_node_token="$(pass_get "$PASS_PREFIX/k3s/server_node_token")"

cat >"$ROOT_DIR/terraform/terraform.auto.tfvars.json" <<EOF
{
  "proxmox_password": "${proxmox_password}"
}
EOF

cat >"$ROOT_DIR/ansible/inventories/lab/group_vars/all.secrets.yml" <<EOF
caddy_cloudflare_api_token: "${caddy_cloudflare_api_token}"
cloudflared_tunnel_token: "${cloudflared_tunnel_token}"
pihole_web_password: "${pihole_web_password}"
vault_root_token: "${vault_root_token}"
k3s_server_node_token: "${k3s_server_node_token}"
EOF

cat >"$ROOT_DIR/.env.homelab" <<EOF
CLOUDFLARE_API_TOKEN=${caddy_cloudflare_api_token}
CLOUDFLARED_TUNNEL_TOKEN=${cloudflared_tunnel_token}
PIHOLE_WEB_PASSWORD=${pihole_web_password}
EOF

echo "rendered:"
echo "  terraform/terraform.auto.tfvars.json"
echo "  ansible/inventories/lab/group_vars/all.secrets.yml"
echo "  .env.homelab"
