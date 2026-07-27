#!/usr/bin/env bash
# Create an encrypted Forgejo administrator Secret without writing plaintext to
# the repository or terminal. Run on the Mac from the repository root.
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
output="$repo_root/apps/forgejo/admin.sops.yaml"

for command in kubectl sops; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "Required command not found: $command" >&2
    exit 1
  fi
done

read -r -p "Forgejo administrator username [ryan]: " username
username=${username:-ryan}
if [[ "$username" == "admin" ]]; then
  echo "Forgejo does not permit 'admin' as the administrator username." >&2
  exit 1
fi

read -r -s -p "Forgejo administrator password: " password
echo
read -r -s -p "Confirm password: " password_confirm
echo
if [[ -z "$password" || "$password" != "$password_confirm" ]]; then
  echo "Passwords are empty or do not match." >&2
  exit 1
fi
unset password_confirm

mkdir -p "$(dirname "$output")"
umask 077

# SOPS reads the repository's public age recipient from .sops.yaml. The
# plaintext exists only in the pipeline between kubectl and sops.
kubectl -n forgejo create secret generic forgejo-admin \
  --from-literal=username="$username" \
  --from-literal=password="$password" \
  --dry-run=client -o yaml | \
  sops --config "$repo_root/.sops.yaml" --encrypt \
    --input-type yaml --output-type yaml --filename-override "$output" \
    /dev/stdin > "$output"

unset password

echo "Wrote encrypted secret: $output"
echo "Inspect it only with: sops --decrypt $output"
echo "Commit the encrypted file; do not apply it directly with kubectl."
