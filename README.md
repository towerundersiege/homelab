# Homelab

This repo deploys a small single-host Docker homelab. It is intentionally just Compose files, a Caddyfile, a `.env` file for local secrets/config, and one idempotent deployment script.

## What Runs

Public through Cloudflare Tunnel:

- `jellyfin.towerundersiege.com` -> Jellyfin
- `navidrome.towerundersiege.com` -> Navidrome

Private over Tailscale:

- `syncthing.towerundersiege.com` -> Syncthing
- `filebrowser.towerundersiege.com` -> File Browser

Infrastructure:

- `cloudflared` keeps the public tunnel open.
- `caddy` terminates HTTPS for Tailscale/private hostnames.
- Tailscale runs on the host, not in Docker, so Tailscale SSH reaches the machine itself.

## Repo Layout

```text
compose.yaml          # stack entrypoint
compose/*.yaml        # one service per file
Caddyfile             # hostname routing
scripts/deploy.sh     # host bootstrap and app deployment
.env.example          # template for local, untracked .env
```

## Secrets And Local Config

Credentials live in `.env`. That file is excluded from Git and `scripts/deploy.sh` sets it to mode `0600`.

Create it from the template:

```sh
cp .env.example .env
chmod 0600 .env
vim .env
```

Required values:

- `CLOUDFLARE_API_TOKEN`: Cloudflare token with DNS edit access for Caddy DNS-01 certificates.
- `CLOUDFLARED_TUNNEL_TOKEN`: Cloudflare Tunnel token.
- `TAILSCALE_IP`: the host's Tailscale IPv4 address, filled in after `tailscale up`.

Storage defaults preserve the current `penzance` layout:

- app config/state: `/var/lib/penzance/config`
- shared files: `/srv/shared`
- media: `/srv/shared/media`
- sync: `/srv/shared/sync`

Override those paths in `.env` if the bare-metal host uses different mounts.

## Install Debian

1. Download the Debian netinst ISO for the machine architecture.
2. Write it to a USB stick.
3. Boot the machine from USB.
4. Install Debian using the normal guided installer.
5. Use the hostname you want for the box, for example `penzance`.
6. Create the normal operator user, for example `ryan`.
7. Select only the base system and SSH server. A desktop environment is not needed.
8. Install the bootloader to the main OS disk.
9. Reboot into Debian and log in as the operator user.

After first login, install enough tooling to fetch this repo:

```sh
sudo apt-get update
sudo apt-get install -y git sudo curl
sudo usermod -aG sudo "$USER"
```

Log out and back in if the user was newly added to `sudo`.

## Prepare Storage

Mount or attach the storage that should hold media and sync data before deploying.

The default layout is:

```text
/srv/shared
/srv/shared/media
/srv/shared/media/music
/srv/shared/media/movies
/srv/shared/media/tv
/srv/shared/sync
```

If this is a fresh disk, create a persistent mount in `/etc/fstab` first. The deploy script creates directories and permissions, but it does not partition, format, or mount disks.

## Fetch The Repo

```sh
git clone git@github.com:towerundersiege/homelab.git
cd homelab
cp .env.example .env
chmod 0600 .env
vim .env
```

If SSH keys for GitHub are not set up on the new host yet, use the HTTPS clone URL instead.

## One-Time Cloudflare Setup

This repo does not create Cloudflare DNS records or tunnels. Those are one-time control-plane setup.

### Tunnel

Create one Cloudflare Tunnel in Cloudflare Zero Trust.

Configure public hostname ingress:

- `jellyfin.towerundersiege.com` -> `http://jellyfin:8096`
- `navidrome.towerundersiege.com` -> `http://navidrome:4533`

Copy the tunnel token into `.env` as:

```sh
CLOUDFLARED_TUNNEL_TOKEN=...
```

No public tunnel route is needed for Syncthing or File Browser.

### DNS

Create DNS-only records for the private services pointing at the host's Tailscale IP:

- `syncthing.towerundersiege.com`
- `filebrowser.towerundersiege.com`

These records must be DNS-only, not proxied. Cloudflare cannot proxy traffic to a Tailscale `100.x.y.z` address.

Public service records can be managed by the Cloudflare Tunnel workflow.

### Caddy Token

Create a Cloudflare API token with DNS edit access for `towerundersiege.com`.

Put it in `.env` as:

```sh
CLOUDFLARE_API_TOKEN=...
```

## One-Time Tailscale Setup

Run the deploy script once first so it installs Tailscale:

```sh
./scripts/deploy.sh
```

Then authenticate the host and enable Tailscale SSH:

```sh
sudo tailscale up --ssh
tailscale ip -4
```

Put the Tailscale IPv4 address into `.env`:

```sh
TAILSCALE_IP=100.x.y.z
```

Update the Cloudflare DNS-only private records to point at that same Tailscale IP.

## Deploy

Run:

```sh
./scripts/deploy.sh
```

The script is safe to rerun. It converges the host by:

- installing required Debian packages
- enabling unattended apt upgrades
- installing and enabling Docker
- installing and enabling Tailscale
- creating the `homelab` group if needed
- adding the operator user to `docker` and `homelab`
- creating storage/config directories
- applying group/setgid permissions for media and sync directories
- copying `Caddyfile` into the Caddy config path
- pulling images
- starting the Compose stack
- enabling a weekly systemd timer for Compose image updates

After the first run, log out and back in so your shell sees the new `docker` group membership.

## Verify

Check containers:

```sh
docker compose ps
```

Check logs:

```sh
docker compose logs -f caddy
docker compose logs -f cloudflared
docker compose logs -f jellyfin
docker compose logs -f navidrome
```

Check host services:

```sh
systemctl status docker
systemctl status tailscaled
systemctl list-timers apt-daily.timer apt-daily-upgrade.timer homelab-compose-update.timer
```

Check Tailscale:

```sh
tailscale status
tailscale ssh "$(whoami)@$(hostname)"
```

Check DNS from a device on the tailnet:

```sh
dig syncthing.towerundersiege.com
dig filebrowser.towerundersiege.com
```

Those should resolve to the host's Tailscale IP.

## Maintenance

Routine update:

```sh
cd ~/homelab
git pull
./scripts/deploy.sh
```

The host also has:

- unattended apt upgrades via Debian's apt timers
- weekly Compose image refresh via `homelab-compose-update.timer`

Manually refresh containers:

```sh
docker compose pull
docker compose up -d --remove-orphans
```

Restart a service:

```sh
docker compose restart jellyfin
docker compose restart navidrome
docker compose restart syncthing
docker compose restart filebrowser
docker compose restart caddy
docker compose restart cloudflared
```

Stop everything:

```sh
docker compose down
```

Back up at least:

```text
.env
/var/lib/penzance/config
/srv/shared/media
/srv/shared/sync
```

The `.env` file contains live credentials. Keep backups encrypted.

## Moving The Machine

The box should survive moving to another network because:

- cloudflared only needs outbound internet access
- Tailscale only needs outbound internet access
- private DNS points at the stable Tailscale IP

After plugging in somewhere else:

```sh
systemctl status tailscaled
systemctl status docker
docker compose ps
```

If the Tailscale IP changes, update `TAILSCALE_IP` in `.env`, update the Cloudflare DNS-only private records, then rerun:

```sh
./scripts/deploy.sh
```
