#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ ! -f .env ]]; then
  cp .env.example .env
  chmod 0600 .env
  echo "Created .env from .env.example. Fill in local paths, Cloudflare values, TAILSCALE_IP, then rerun." >&2
  exit 1
fi

chmod 0600 .env

set -a
# shellcheck disable=SC1091
source .env
set +a

: "${CONFIG_ROOT:=/var/lib/homelab/config}"
: "${FILES_ROOT:=/srv}"
: "${MEDIA_ROOT:=/srv/media}"
: "${SYNC_ROOT:=/srv/sync}"
: "${PUID:=1000}"
: "${PGID:=1000}"
: "${SERVICE_USER:=${SUDO_USER:-$(id -un)}}"
: "${SERVICE_GROUP:=homelab}"
: "${SERVICE_GROUP_GID:=$PGID}"

sudo -v

if [[ "$(id -u)" -eq 0 ]]; then
  echo "Run this script as the operator user, not root. It uses sudo when needed." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

install_packages() {
  local packages=("$@")
  sudo apt-get install -y "${packages[@]}"
}

configure_unattended_upgrades() {
  sudo install -d -m 0755 /etc/apt/apt.conf.d
  sudo tee /etc/apt/apt.conf.d/20auto-upgrades >/dev/null <<'EOF_AUTO_UPGRADES'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF_AUTO_UPGRADES

  sudo tee /etc/apt/apt.conf.d/51homelab-unattended-upgrades >/dev/null <<'EOF_UNATTENDED'
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
EOF_UNATTENDED

  sudo systemctl enable --now apt-daily.timer apt-daily-upgrade.timer
}

configure_docker_repo() {
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg | sudo tee /etc/apt/keyrings/docker.asc >/dev/null
  sudo chmod a+r /etc/apt/keyrings/docker.asc

  . /etc/os-release
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian ${VERSION_CODENAME} stable" |
    sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
}

ensure_tailscale() {
  if ! command -v tailscale >/dev/null 2>&1; then
    curl -fsSL https://tailscale.com/install.sh | sh
  fi
  sudo systemctl enable --now tailscaled
}

configure_users() {
  if ! getent group "$SERVICE_GROUP" >/dev/null; then
    if getent group "$SERVICE_GROUP_GID" >/dev/null; then
      echo "Group id $SERVICE_GROUP_GID already exists but is not $SERVICE_GROUP. Update .env before deploying." >&2
      exit 1
    fi
    sudo groupadd --gid "$SERVICE_GROUP_GID" "$SERVICE_GROUP"
  fi

  local current_gid
  current_gid="$(getent group "$SERVICE_GROUP" | cut -d: -f3)"
  if [[ "$current_gid" != "$PGID" ]]; then
    echo "SERVICE_GROUP $SERVICE_GROUP has gid $current_gid but PGID is $PGID. Make them match in .env." >&2
    exit 1
  fi

  sudo usermod -aG docker "$SERVICE_USER"
  sudo usermod -aG "$SERVICE_GROUP" "$SERVICE_USER"
}

create_directories() {
  sudo install -d -m 0755 \
    "$CONFIG_ROOT" \
    "$CONFIG_ROOT/caddy" \
    "$CONFIG_ROOT/caddy/config" \
    "$CONFIG_ROOT/caddy/data" \
    "$CONFIG_ROOT/filebrowser" \
    "$CONFIG_ROOT/jellyfin" \
    "$CONFIG_ROOT/navidrome" \
    "$CONFIG_ROOT/syncthing" \
    "$FILES_ROOT" \
    "$MEDIA_ROOT" \
    "$MEDIA_ROOT/music" \
    "$MEDIA_ROOT/movies" \
    "$MEDIA_ROOT/tv" \
    "$SYNC_ROOT"

  sudo install -m 0644 Caddyfile "$CONFIG_ROOT/caddy/Caddyfile"
  sudo chown -R "$PUID:$PGID" "$CONFIG_ROOT/filebrowser" "$CONFIG_ROOT/navidrome" "$CONFIG_ROOT/syncthing" "$SYNC_ROOT"
  sudo chgrp -R "$SERVICE_GROUP" "$MEDIA_ROOT" "$SYNC_ROOT"
  sudo chmod -R g+rwX "$MEDIA_ROOT" "$SYNC_ROOT"
  sudo find "$MEDIA_ROOT" "$SYNC_ROOT" -type d -exec chmod g+s {} +
}

configure_compose_timer() {
  local docker_bin
  docker_bin="$(command -v docker)"

  sudo tee /etc/systemd/system/homelab-compose-update.service >/dev/null <<EOF_SERVICE
[Unit]
Description=Pull and apply homelab Docker Compose updates
Requires=docker.service
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
WorkingDirectory=$ROOT_DIR
ExecStart=$docker_bin compose pull
ExecStart=$docker_bin compose up -d --remove-orphans
EOF_SERVICE

  sudo tee /etc/systemd/system/homelab-compose-update.timer >/dev/null <<'EOF_TIMER'
[Unit]
Description=Weekly homelab Docker Compose update

[Timer]
OnCalendar=Sun 04:30
Persistent=true
RandomizedDelaySec=30m

[Install]
WantedBy=timers.target
EOF_TIMER

  sudo systemctl daemon-reload
  sudo systemctl enable --now homelab-compose-update.timer
}

sudo apt-get update
install_packages \
  apt-listchanges \
  ca-certificates \
  curl \
  dnsutils \
  gnupg \
  htop \
  jq \
  less \
  rsync \
  tmux \
  unattended-upgrades \
  vim

configure_unattended_upgrades
configure_docker_repo
sudo apt-get update
install_packages docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo systemctl enable --now docker
configure_users
ensure_tailscale
create_directories

sudo docker compose pull
sudo docker compose up -d --remove-orphans
configure_compose_timer

cat <<EOF
Deployment complete.

The user $SERVICE_USER is a member of docker and $SERVICE_GROUP. New login
sessions can use docker without sudo.

One-time Tailscale setup, if not already done:
  sudo tailscale up --ssh
  tailscale ip -4

Set TAILSCALE_IP in .env to that address, then rerun if it changed:
  ./scripts/deploy.sh
EOF
