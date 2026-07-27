#!/usr/bin/env bash
# Establish persistent host directories before any Kubernetes PVC is created.
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Run this script with sudo." >&2
  exit 1
fi

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source_file="$repo_root/systemd/tmpfiles.d/homelab-operational.conf"
target_file="/etc/tmpfiles.d/homelab-operational.conf"

install -D -m 0644 "$source_file" "$target_file"
systemd-tmpfiles --create "$target_file"

echo "Host operational storage is ready at /srv/operational."
echo "Flux will direct new homelab-local PVCs to /srv/operational/k3s/local-path."
