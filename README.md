# Homelab

This is the external, recoverable source of truth for the `homelab` host: a
portable, single-node Debian 13 ThinkCentre. The intended steady state is K3s
with Cilium networking and Flux GitOps. Host-level Tailscale, Pi-hole, and the
MergerFS media pool deliberately remain independent of Kubernetes so remote
access, DNS recovery, and data mounts do not depend on the cluster.

## Current state

- Debian 13 is installed bare metal as `homelab` at DHCP reservation
  `192.168.1.101`.
- Passwordless SSH and Tailscale SSH are working.
- The retained 8 TB ext4 DAS disk is labelled `stardust`, mounted at
  `/mnt/disks/stardust`, and exposed by MergerFS at `/mnt/crimson`.
- K3s `v1.36.1+k3s1`, Cilium `1.19.6`, and Flux are healthy. The
  Flux-managed Traefik ingress owns the reserved `192.168.1.102` address;
  Cilium provides its L2 advertisement and load balancing.
- Pi-hole runs natively on the host and serves the private DNS boundary:
  `pihole.home.rpca.uk` resolves to `.101`; `*.home.rpca.uk` resolves to
  `.102`. It has not yet been advertised through router DHCP.

The verified pre-reinstall archive remains on the media disk at
`/mnt/crimson/media/homelab-migration/pre-debian-20260726-verified`.

## Layout

```text
apps/                  Application namespaces and releases
clusters/homelab/      Flux entry point and reconciliation order
infrastructure/        Cluster-wide controllers and configuration
systemd/               Minimal tracked host boot configuration
docs/                  Installation, recovery, and bootstrap runbooks
scripts/               Explicit host bootstrap helpers
compose/               Legacy Compose manifests retained for migration reference
```

Do not commit plaintext secrets, credentials, private keys, Cloudflare tokens,
or Tailscale state. Once configured, encrypted SOPS manifests may be committed;
the local age recovery key must remain outside Git.

## Bootstrap order

1. Follow [the Debian installation runbook](docs/install-debian-macos.md) for
   the hardware baseline and storage recovery details.
2. On `homelab`, clone this repository and run the host CLI setup if desired:

   ```sh
   bash scripts/bootstrap-host-cli.sh
   ```

3. Bootstrap the cluster with the pinned, repeat-safe script:

   ```sh
   sudo bash scripts/bootstrap-k3s-cilium.sh
   ```

4. Follow [the GitOps bootstrap runbook](docs/gitops-bootstrap.md) from the
   Mac to install Flux from this existing GitHub repository.

5. Follow [the host Pi-hole runbook](docs/pihole-host.md) to establish private
   DNS before deploying applications.

After Flux is managing the cluster, add infrastructure and applications through
Git commits. Do not deploy long-lived applications directly with `kubectl`.

## Network model

- Tailscale provides administration anywhere with outbound internet access.
- Pi-hole will run on the host at `192.168.1.101` and answer
  `pihole.home.rpca.uk` itself.
- Traefik will receive the reserved LAN address `192.168.1.102` and serve
  private application names such as `forgejo.home.rpca.uk`.
- Cloudflare Tunnel will expose only `media.rpca.uk` (Jellyfin) and
  `music.rpca.uk` (Navidrome). Everything else remains LAN/Tailscale-only.
  Follow [the Cloudflare Tunnel runbook](docs/cloudflare-tunnel.md) to create
  the encrypted connector credential and the two dashboard routes.
- VPN-required future workloads use a Gluetun sidecar with Mullvad WireGuard;
  see [the Gluetun runbook](docs/gluetun-mullvad.md). It does not alter current
  service networking.

## Storage model

`crimson` is a MergerFS pool. Today it contains only `stardust` and has no
redundancy. When a second DAS disk is added, name it `archfiend` and use it as
SnapRAID parity before considering the pool protected. The future internal 2–4
TB disk is intended to become the active/portable tier; the DAS remains bulk
archive storage.

Application state is separate from media: Flux configures the retained
`homelab-local` StorageClass under `/srv/operational` on the NVMe. See
[the Kubernetes storage runbook](docs/kubernetes-storage.md).

The first persistent application is Forgejo. Its administrator Secret is
created locally and encrypted with SOPS; see [the Forgejo bootstrap
runbook](docs/forgejo-bootstrap.md).

To mirror the committed history of local projects into private Forgejo
repositories without changing their GitHub remotes, follow [the local import
runbook](docs/forgejo-local-import.md).
