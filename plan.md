# Homelab rebuild plan

## Goal

Replace the current Penzance Proxmox VM with a small, portable bare-metal Debian
host named `homelab` on the ThinkCentre M75q-1. Most applications run on a
single-node K3s cluster with Cilium and Flux; the host retains only the services
needed to make boot, DNS, storage, and remote recovery dependable.

The system must recover after power and network changes with no manual
application starts: it needs power, Ethernet with DHCP, and outbound internet.
Tailscale provides remote administration and Cloudflare Tunnel keeps explicitly
public media services reachable.

## Decisions

- **Host:** Debian 13 on the 256 GB NVMe, hostname `homelab`; the installed
  guided-LVM layout has a 224.5 GB root logical volume and 12 GB swap. Keep
  operational data on the root filesystem initially at `/srv/operational`;
  there is no separate home logical volume to manage.
- **Host-level exceptions:** Tailscale with Tailscale SSH, Pi-hole, DAS mounts,
  MergerFS/SnapRAID, backup scripts, and the minimal systemd bootstrap units.
- **Kubernetes:** K3s with Flannel, kube-proxy, ServiceLB, and Traefik disabled;
  Cilium supplies CNI, kube-proxy replacement, Hubble, Gateway API, LB IPAM,
  and L2 announcements.
- **LAN addresses:** DHCP reserves `homelab` `.101` on `192.168.1.0/24`; the
  host-level Pi-hole also uses that address. Reserve `.102` exclusively for
  Cilium's Gateway `LoadBalancer` address; NAS remains `.100`.
- **DNS and routes:** Host Pi-hole serves `pihole.home.rpca.uk` directly and
  returns the Cilium Gateway IP for app names such as
  `media.home.rpca.uk`, `music.home.rpca.uk`, and `forgejo.home.rpca.uk`.
  cert-manager uses a scoped Cloudflare DNS-01 token for `*.home.rpca.uk`.
- **Public exposure:** Cloudflare Tunnel is the only public ingress. It exposes
  `media.rpca.uk` for Jellyfin and `music.rpca.uk` for Navidrome; all other
  services are LAN/Tailscale only.
- **Storage:** DAS members use Yu-Gi-Oh! 5D’s dragon labels. The existing 8 TB
  ext4 disk is labelled `stardust`, mounted at `/mnt/disks/stardust` by UUID;
  MergerFS presents it at `/mnt/crimson`. It is temporarily unprotected until
  `archfiend` is added as the first SnapRAID parity disk. A future 2–4 TB
  internal disk becomes the active/portable tier; the DAS becomes bulk/archive
  storage.
- **GitOps:** An external private Git repository is Flux’s authoritative,
  recoverable source. Forgejo is a LAN/Tailscale-only service and mirror, never
  the sole bootstrap dependency. SOPS+age encrypts secrets in Git.
- **Artifacts:** Forgejo’s private OCI registry serves custom immutable images
  and Helm charts. All deployment references use pinned versions/digests, never
  `latest`.
- **Documentation:** The external Git repository owns canonical recovery and
  maintenance runbooks under `docs/`. Forgejo’s integrated wiki holds informal
  notes and project knowledge.
- **Updates:** Debian receives unattended security updates without automatic
  reboots. Renovate opens weekly update PRs for K3s, Cilium, Flux, Helm charts,
  and images; patch/digest PRs may auto-merge after checks, while minor/major
  updates are reviewed. Flux applies merged changes.
- **Operations:** Keep monitoring lightweight: Homepage for links, Headlamp for
  Kubernetes inspection, Uptime Kuma for availability checks, ntfy for alerts,
  and Hubble for Cilium networking. Do not install Grafana/Prometheus or
  Portainer initially.
- **Backups:** Make manual encrypted external-drive backups of `/srv/operational`,
  Forgejo data, application database dumps, and the Flux/SOPS recovery bundle.
  NAS-only copies are acceptable for this non-critical system; periodically
  restore one database or config directory to verify the process.

## Portability boundary

On any network with DHCP and outbound internet, host boot, Tailscale access,
Cloudflare Tunnel, and already-reconciled workloads recover automatically.
Public media access therefore continues. `*.home.rpca.uk` for arbitrary LAN
clients requires that network’s router/DHCP to advertise Pi-hole; do not run a
competing DHCP server on unfamiliar networks. Configure Tailscale split DNS to
send `home.rpca.uk` queries from tailnet devices to Pi-hole, so the owner’s
Tailscale devices retain those names away from home.

## Bootstrap and boot sequence

1. Debian mounts `/mnt/disks/stardust` by UUID and `crimson` through MergerFS
   before K3s starts. `/srv/operational` is created on the NVMe root filesystem.
2. Systemd starts Tailscale and host Pi-hole independently of Kubernetes.
3. A documented, idempotent host bootstrap installs/verifies a pinned K3s with
   bundled networking disabled, then Cilium. Flux is bootstrapped only after
   Cilium is healthy, from the external Git repository.
4. Flux reconciles, in order: SOPS and
   Gateway API configuration/cert-manager; storage definitions; cloudflared;
   then applications.
5. Pi-hole is advertised by router DHCP only after DNS health checks pass.

Do not make K3s depend on Pi-hole, Forgejo, cloudflared, or media availability.
They must be able to recover independently after a failed cluster startup.

## Forgejo and automation

- Deploy Forgejo with persistent local storage and its registry route (`/v2`)
  behind the private Gateway hostname. Use a current Forgejo LTS line.
- Initially build custom images/charts on the Mac and push versioned OCI
  artifacts to Forgejo.
- Add one Forgejo Actions runner only when local CI is useful. It is a separate,
  repository- or organisation-scoped worker that polls Forgejo and starts
  short-lived job containers. Run it as a rootless-Podman systemd service on the
  host rather than adding privileged Docker-in-Docker to K3s.
- Restrict the runner to trusted private repositories and protected branches;
  it has no Kubernetes admin credential and uses a narrowly scoped registry
  token. A future Kubernetes Job/ephemeral-runner system is explicitly out of
  scope until this small runner is insufficient.

## Migration sequence

1. **Complete backup:** stop current Penzance containers briefly; archive
   `/var/lib/penzance/config`, Docker volumes, `/etc`, `/home/ryan`, container
   inspection metadata, and Docker state to a new media-drive directory. Record
   SHA-256 checksums and verify the archive before restarting the containers.
   - Completed 2026-07-26 at
     `/srv/shared/media/homelab-migration/pre-debian-20260726-verified`.
     `penzance-state.tar.gz` is 4.8 GB, has a SHA-256 manifest, passed gzip and
     full tar listing validation, and has a `BACKUP_COMPLETE` marker.
2. **Wipe and install:** after the archive is verified, install Debian using
   [`docs/install-debian-macos.md`](docs/install-debian-macos.md). Disconnect
   the DAS while installing.
3. **Prepare storage:** completed 2026-07-26. The existing data disk was
   retained, labelled `stardust`, mounted at `/mnt/disks/stardust`, and exposed
   through a boot-tested one-disk MergerFS pool at `/mnt/crimson`. Configure
   SMART/SnapRAID jobs when parity storage exists; do not treat current
   one-disk `crimson` as protected storage.
4. **Foundation:** configure Tailscale, host Pi-hole, K3s, Cilium, Flux, SOPS,
   private certificates, the shared Gateway, and Cloudflare Tunnel.
5. **Applications:** deploy and restore Jellyfin first, then Navidrome, Forgejo,
   Homepage, Headlamp, Uptime Kuma, ntfy, and optional Forgejo runner.
6. **Validation:** reboot the host; recreate application pods; validate LAN DNS,
   Tailscale SSH/split DNS, public media routes, Flux reconciliation, registry
   pulls, and one backup restore.

## Completed rebuild milestones

- **2026-07-26:** Debian 13 installed bare metal as `homelab` with Tailscale
  and Tailscale SSH working.
- **2026-07-26:** retained DAS disk mounted as `stardust`; one-disk MergerFS
  pool `crimson` verified after reboot.
- **2026-07-26:** K3s `v1.36.1+k3s1` installed with bundled networking,
  kube-proxy, ServiceLB, and Traefik disabled. Cilium `1.19.6` is healthy with
  kube-proxy replacement, Hubble, Gateway API, and L2 announcements enabled.
  Enable Cilium's legacy host-routing path for reliable transparent-proxy
  handling of LAN Gateway traffic on this host, with BPF TPROXY enabled.
- **2026-07-26:** Flux bootstrapped from `towerundersiege/homelab` using a
  read-only GitHub SSH deploy key; Flux controllers and initial sync are
  healthy. The GitHub token used to create the deploy key is not stored in the
  cluster.
- **2026-07-26:** Cilium L2 announced the dedicated LAN Gateway IP
  `192.168.1.102`; it is reachable from the LAN and returns Envoy's expected
  `404` until application `HTTPRoute` objects are deployed. Host Pi-hole is
  the next bootstrap step; its configuration and recovery instructions are in
  [`docs/pihole-host.md`](docs/pihole-host.md).
- **2026-07-26:** native host Pi-hole installed and verified. It safely accepts
  LAN and authenticated-Tailscale DNS queries, serves `pihole.home.rpca.uk` at
  `.101`, and sends the `home.rpca.uk` wildcard to the Cilium Gateway at
  `.102`. Its all-interface listener requires that no WAN DNS port-forward is
  ever configured. Configure router DHCP DNS only after this verification.

## Current migration source

- Penzance is a KVM VM with 4 vCPU, 15 GiB RAM, a full 48 GB root disk, and an
  NFS media mount at `/srv/shared` from `192.168.1.100`.
- Active state is under `/var/lib/penzance/config`; active containers include
  Jellyfin, Navidrome, cloudflared, Caddy, Pi-hole, Syncthing, Filebrowser,
  Portainer, Isambard, and Gluetun.
- Only Jellyfin, Navidrome, Pi-hole, cloudflared, Forgejo, and the lightweight
  operating stack move in the initial release. Archive other service state for
  later decisions.
- After the verified backup, the current containers cannot be restarted because
  Docker cannot allocate runtime mount directories on the full root disk. This
  does not affect the verified backup; do not clean images or other data unless
  temporary recovery of the old VM is required before the wipe.
