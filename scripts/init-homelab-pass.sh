#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS_STORE_DIR="${HOMELAB_PASSWORD_STORE_DIR:-$ROOT_DIR/.homelab-pass}"
HOMELAB_GPG_NAME="${HOMELAB_GPG_NAME:-Homelab Infrastructure}"
HOMELAB_GPG_EMAIL="${HOMELAB_GPG_EMAIL:-homelab@towerundersiege.com}"
HOMELAB_GPG_UID="${HOMELAB_GPG_UID:-${HOMELAB_GPG_NAME} <${HOMELAB_GPG_EMAIL}>}"
HOMELAB_GPG_PASSPHRASE="${HOMELAB_GPG_PASSPHRASE:-}"
PASS_PREFIX="${HOMELAB_PASS_PREFIX:-homelab}"
export PASSWORD_STORE_DIR="$PASS_STORE_DIR"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing required command: $1" >&2
    exit 1
  }
}

require_cmd gpg
require_cmd pass

mkdir -p "$PASS_STORE_DIR"

if ! gpg --list-secret-keys "$HOMELAB_GPG_UID" >/dev/null 2>&1; then
  if [[ -z "$HOMELAB_GPG_PASSPHRASE" ]]; then
    echo "HOMELAB_GPG_PASSPHRASE is not set. Refusing to create an unprotected homelab key." >&2
    exit 1
  fi

  gpg --batch --pinentry-mode loopback --passphrase "$HOMELAB_GPG_PASSPHRASE" \
    --quick-generate-key "$HOMELAB_GPG_UID" ed25519 cert,sign 2y

  fingerprint="$(gpg --list-secret-keys --with-colons "$HOMELAB_GPG_UID" | awk -F: '/^fpr:/ {print $10; exit}')"
  gpg --batch --pinentry-mode loopback --passphrase "$HOMELAB_GPG_PASSPHRASE" \
    --quick-add-key "$fingerprint" cv25519 encr 2y
fi

pass init -p "$PASS_PREFIX" "$HOMELAB_GPG_UID"

echo "initialized homelab pass store at $PASS_STORE_DIR with subtree '$PASS_PREFIX/' for $HOMELAB_GPG_UID"
echo "seed these entries next:"
echo "  pass insert $PASS_PREFIX/proxmox/password"
echo "  pass insert $PASS_PREFIX/cloudflare/caddy_api_token"
echo "  pass insert $PASS_PREFIX/cloudflare/tunnel_token"
echo "  pass insert $PASS_PREFIX/pihole/web_password"
echo "  pass insert $PASS_PREFIX/vault/root_token"
echo "  pass insert $PASS_PREFIX/k3s/server_node_token"
