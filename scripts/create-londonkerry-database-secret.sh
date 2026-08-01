#!/usr/bin/env bash
# Create the encrypted database Secret for the LondonKerry WordPress migration.
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
output="$repo_root/apps/londonkerry/database.sops.yaml"

for command in kubectl openssl sops; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "Required command not found: $command" >&2
    exit 1
  fi
done

umask 077
root_password=$(openssl rand -base64 36)
database_password=$(openssl rand -base64 36)

kubectl -n londonkerry create secret generic database \
  --from-literal=db-name=wordpress \
  --from-literal=db-user=wordpress \
  --from-literal=db-password="$database_password" \
  --from-literal=db-root-password="$root_password" \
  --dry-run=client -o yaml | \
  sops --config "$repo_root/.sops.yaml" --encrypt \
    --input-type yaml --output-type yaml --filename-override "$output" \
    /dev/stdin > "$output"

unset root_password database_password
echo "Created encrypted $output. Commit and push it before Flux can start LondonKerry."
