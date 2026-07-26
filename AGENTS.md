# AGENTS

## Purpose

This repo manages a pared-down single-host Docker homelab. The active deployment is Compose plus a host-level Tailscale daemon.

## Operating Rules

- Do not commit `.env`, rendered secrets, private keys, or Tailscale/Cloudflare tokens.
- Keep the deployment simple: one `compose/*.yaml` file per service, root `compose.yaml` as the stack entrypoint, and `scripts/deploy.sh` as the deploy path.
- Public services are Jellyfin and Navidrome through Cloudflare Tunnel.
- No private app services are currently deployed. Caddy remains in the stack for future Tailscale-private HTTPS routes.
- Tailscale runs on the host, not as a container, so Tailscale SSH reaches the host itself.
- Avoid reintroducing Ansible, Terraform, Proxmox lifecycle management, Kubernetes, Flux, monitoring, Pi-hole, Portainer, or Isambard unless explicitly requested.

## Required Paths

- stack entrypoint: [compose.yaml](/Users/ryan/Projects/homelab/compose.yaml)
- service compose files: [compose](/Users/ryan/Projects/homelab/compose)
- reverse proxy config: [Caddyfile](/Users/ryan/Projects/homelab/Caddyfile)
- deploy script: [scripts/deploy.sh](/Users/ryan/Projects/homelab/scripts/deploy.sh)
- environment template: [.env.example](/Users/ryan/Projects/homelab/.env.example)
- README: [README.md](/Users/ryan/Projects/homelab/README.md)
