#!/usr/bin/env bash
# Store the Forgejo UI-created runner connection as an encrypted GitOps Secret.
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
output="$repo_root/apps/forgejo/runner.sops.yaml"
kustomization="$repo_root/apps/forgejo/kustomization.yaml"

for command in kubectl sops; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "Required command not found: $command" >&2
    exit 1
  fi
done

read -r -p "Forgejo URL [https://forgejo.home.rpca.uk/]: " forgejo_url
forgejo_url=${forgejo_url:-https://forgejo.home.rpca.uk/}
read -r -p "Runner UUID: " runner_uuid
read -r -s -p "Runner token: " runner_token
echo
if [[ -z "$runner_uuid" || -z "$runner_token" ]]; then
  echo "Runner UUID and token are required." >&2
  exit 1
fi

mkdir -p "$(dirname "$output")"
umask 077
kubectl -n forgejo create secret generic homelab-builder \
  --from-literal=url="$forgejo_url" \
  --from-literal=uuid="$runner_uuid" \
  --from-literal=token="$runner_token" \
  --dry-run=client -o yaml | \
  sops --config "$repo_root/.sops.yaml" --encrypt \
    --input-type yaml --output-type yaml --filename-override "$output" \
    /dev/stdin > "$output"
unset runner_token

for resource in runner.sops.yaml runner.yaml; do
  if ! grep -Fqx "  - $resource" "$kustomization"; then
    temporary=$(mktemp "${kustomization}.XXXXXX")
    awk -v resource="$resource" '
      /resources:/ { print; print "  - " resource; next }
      { print }
    ' "$kustomization" > "$temporary"
    mv "$temporary" "$kustomization"
  fi
done

echo "Wrote encrypted runner credentials and registered the runner in GitOps."
echo "Commit apps/forgejo/runner.sops.yaml and apps/forgejo/kustomization.yaml."
