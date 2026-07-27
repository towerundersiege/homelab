#!/usr/bin/env bash
# Encrypt a downloaded Mullvad WireGuard configuration for Gluetun.
# The WireGuard private key is never printed or written to Git in plaintext.

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 /path/to/mullvad-wireguard.conf" >&2
  exit 1
fi

wireguard_config=$1
if [[ ! -f "${wireguard_config}" ]]; then
  echo "WireGuard configuration not found: ${wireguard_config}" >&2
  exit 1
fi

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
output_path="${repo_root}/apps/vpn/mullvad-wireguard.sops.yaml"
mkdir -p "$(dirname -- "${output_path}")"

for command in kubectl sops; do
  if ! command -v "${command}" >/dev/null 2>&1; then
    echo "Missing required command: ${command}" >&2
    exit 1
  fi
done

umask 077

kubectl -n vpn create secret generic mullvad-wireguard \
  --from-file=wg0.conf="${wireguard_config}" \
  --dry-run=client -o yaml | \
  sops --config "${repo_root}/.sops.yaml" --encrypt \
    --input-type yaml --output-type yaml --filename-override "${output_path}" \
    /dev/stdin >"${output_path}"

echo "Created encrypted ${output_path}. Review, commit, and push it before enabling a VPN-bound workload."
