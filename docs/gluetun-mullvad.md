# Gluetun with Mullvad WireGuard

Gluetun is an opt-in egress boundary for workloads that require a commercial
VPN. It is not a cluster-wide gateway: each VPN-bound application gets a
Gluetun sidecar in the same Pod and therefore shares Gluetun's network
namespace and kill-switch.

Do not place Jellyfin, Navidrome, Forgejo, Pi-hole, Tailscale, Cloudflare Tunnel,
or Flux behind it. They must retain normal LAN and public routing.

## Prepare the Mullvad credential

1. Sign in to Mullvad and generate a dedicated WireGuard configuration for this
   host. Choose the desired exit location and download the `.conf` file.
2. Keep the downloaded file private: it contains the WireGuard private key and
   assigned tunnel address.
3. Create the SOPS-encrypted Kubernetes Secret from the Mac:

   ```sh
   ./scripts/create-mullvad-wireguard-secret.sh \
     ~/Downloads/mullvad-*.conf
   git add apps/vpn/mullvad-wireguard.sops.yaml
   git commit -m 'Add Mullvad WireGuard credential'
   git push
   ```

The `vpn` namespace is already GitOps-managed. Tell Codex once the encrypted
Secret is committed; it is enabled together with the first VPN-bound workload.
Do not create a standalone Gluetun Deployment.

## Workload pattern

The application and its Gluetun sidecar share one Pod. The sidecar needs only
the `NET_ADMIN` capability and the host TUN character device. Mount the
encrypted `mullvad-wireguard` Secret as `/gluetun/wireguard/wg0.conf` and set:

```yaml
env:
  - name: VPN_SERVICE_PROVIDER
    value: custom
  - name: VPN_TYPE
    value: wireguard
```

For an application that has a web UI or receives inbound connections, explicitly
allow only its listening port with Gluetun's `FIREWALL_INPUT_PORTS`. The
application container must not be given host networking, `NET_ADMIN`, or a
separate Kubernetes Service that bypasses its Pod network namespace.

Before publishing the workload, verify its outward address from inside the
application container and verify that stopping Gluetun prevents egress. Mullvad
does not provide port forwarding, so choose clients/services that do not depend
on an inbound forwarded port.
