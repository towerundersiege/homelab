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

pass_get_optional() {
  if pass show "$1" >/dev/null 2>&1; then
    pass show "$1" | head -n 1
  else
    printf ''
  fi
}

require_cmd pass
require_cmd openssl

mkdir -p "$ROOT_DIR/terraform"
mkdir -p "$ROOT_DIR/ansible/inventories/lab/group_vars"

proxmox_password="$(pass_get "$PASS_PREFIX/proxmox/password")"
cloudflare_dns_api_token="$(pass_get_optional "$PASS_PREFIX/cloudflare/dns_api_token")"
if [[ -z "$cloudflare_dns_api_token" ]]; then
  cloudflare_dns_api_token="$(pass_get "$PASS_PREFIX/cloudflare/caddy_api_token")"
fi
cloudflared_tunnel_token="$(pass_get "$PASS_PREFIX/cloudflare/tunnel_token")"
cloudflare_terraform_api_token="$(pass_get_optional "$PASS_PREFIX/cloudflare/terraform_api_token")"
cloudflare_account_id="$(pass_get_optional "$PASS_PREFIX/cloudflare/account_id")"
cloudflare_zone_id="$(pass_get_optional "$PASS_PREFIX/cloudflare/zone_id")"
cloudflare_tunnel_id="$(pass_get_optional "$PASS_PREFIX/cloudflare/tunnel_id")"
pihole_web_password="$(pass_get "$PASS_PREFIX/pihole/web_password")"
vault_root_token="$(pass_get "$PASS_PREFIX/vault/root_token")"
k3s_server_node_token="$(pass_get "$PASS_PREFIX/k3s/server_node_token")"
penzance_ryan_password="$(pass_get "$PASS_PREFIX/hosts/penzance/ryan_password")"
lyonesse_ryan_password="$(pass_get "$PASS_PREFIX/hosts/lyonesse-cp-01/ryan_password")"
penzance_ryan_password_hash="$(printf '%s' "$penzance_ryan_password" | openssl passwd -6 -stdin)"
lyonesse_ryan_password_hash="$(printf '%s' "$lyonesse_ryan_password" | openssl passwd -6 -stdin)"

cat >"$ROOT_DIR/terraform/terraform.auto.tfvars.json" <<EOF
{
  "proxmox_password": "${proxmox_password}",
  "cloudflare_api_token": "${cloudflare_terraform_api_token}",
  "cloudflare_account_id": "${cloudflare_account_id}",
  "cloudflare_zone_id": "${cloudflare_zone_id}",
  "cloudflare_tunnel_id": "${cloudflare_tunnel_id}"
}
EOF

cat >"$ROOT_DIR/ansible/inventories/lab/group_vars/all.secrets.yml" <<EOF
pihole_web_password: "${pihole_web_password}"
vault_root_token: "${vault_root_token}"
k3s_server_node_token: "${k3s_server_node_token}"
ryan_password_hashes:
  penzance: "${penzance_ryan_password_hash}"
  lyonesse-cp-01: "${lyonesse_ryan_password_hash}"
EOF

cat >"$ROOT_DIR/.env.homelab" <<EOF
CLOUDFLARE_API_TOKEN=${cloudflare_dns_api_token}
CLOUDFLARED_TUNNEL_TOKEN=${cloudflared_tunnel_token}
PIHOLE_WEB_PASSWORD=${pihole_web_password}
EOF

echo "rendered:"
echo "  terraform/terraform.auto.tfvars.json"
echo "  ansible/inventories/lab/group_vars/all.secrets.yml"
echo "  .env.homelab"
