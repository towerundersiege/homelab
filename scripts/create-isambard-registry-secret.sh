#!/usr/bin/env bash
# Create the encrypted registry credential used by Flux and the Isambard pod.
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
output="$repo_root/apps/media/isambard-registry.sops.yaml"

for command in kubectl sops; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "Required command not found: $command" >&2
    exit 1
  fi
done

read -r -p "Forgejo username [ryan]: " username
username=${username:-ryan}
read -r -s -p "Forgejo package access token: " token
echo
if [[ -z "$token" ]]; then
  echo "A package access token is required." >&2
  exit 1
fi

mkdir -p "$(dirname "$output")"
umask 077
kubectl -n media create secret docker-registry isambard-registry \
  --docker-server=forgejo.home.rpca.uk \
  --docker-username="$username" \
  --docker-password="$token" \
  --dry-run=client -o yaml | \
  sops --config "$repo_root/.sops.yaml" --encrypt \
    --input-type yaml --output-type yaml --filename-override "$output" \
    /dev/stdin > "$output"
unset token

echo "Wrote encrypted secret: $output"
echo "Commit it; Flux will provide it to the OCI chart source and Isambard pod."
