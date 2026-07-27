#!/usr/bin/env bash
# Create the SOPS-encrypted token for the remotely managed Cloudflare Tunnel.
# The token is never printed or written to Git in plaintext.

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
output_path="${repo_root}/infrastructure/cloudflare-tunnel/cloudflared-token.sops.yaml"

for command in kubectl sops; do
  if ! command -v "${command}" >/dev/null 2>&1; then
    echo "Missing required command: ${command}" >&2
    exit 1
  fi
done

read -r -s -p 'Cloudflare Tunnel token: ' tunnel_token
printf '\n'

if [[ -z "${tunnel_token}" ]]; then
  echo 'A Cloudflare Tunnel token is required.' >&2
  exit 1
fi

umask 077

kubectl -n cloudflare-tunnel create secret generic cloudflared-token \
  --from-literal=token="${tunnel_token}" \
  --dry-run=client -o yaml | \
  sops --config "${repo_root}/.sops.yaml" --encrypt \
    --input-type yaml --output-type yaml --filename-override "${output_path}" \
    /dev/stdin >"${output_path}"

unset tunnel_token

echo "Created encrypted ${output_path}. Review, commit, and push it; Flux will apply it."
