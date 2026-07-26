# Host Pi-hole DNS

Pi-hole is intentionally a native host service, not a Kubernetes workload. It
is the small DNS boundary that makes local service names work even while K3s is
restarting. It starts through the `pihole-FTL.service` systemd unit.

## Intended records

| Name | Address | Owner |
| --- | --- | --- |
| `pihole.home.rpca.uk` | `192.168.1.101` | host Pi-hole web UI |
| `*.home.rpca.uk` | `192.168.1.102` | Cilium LAN Gateway |

The wildcard is a DNS routing rule only. An application needs its own Flux
managed `HTTPRoute` before its hostname produces anything other than Envoy's
expected `404` response.

## Install on `homelab`

The host uses DHCP so it remains portable; keep the router's `.101` DHCP
reservation. If the installer asks about network configuration, use
`enp3s0f0` and retain DHCP rather than setting a hard-coded address.

Run the official installer interactively:

```sh
ssh -t homelab
curl -sSL https://install.pi-hole.net | bash
```

During the installer:

- Select `enp3s0f0` if asked for an interface.
- Keep the current network/DHCP configuration.
- Choose any upstream temporarily; the repository configuration below replaces
  it with Cloudflare's `1.1.1.1` and `1.0.0.1`.
- Keep the displayed admin password private. It is not a Git secret. Reset it
  later with `sudo pihole setpassword` if necessary.

Then, from the cloned repository on the host:

```sh
cd ~/homelab
sudo bash scripts/configure-pihole.sh
```

The script uses Pi-hole v6's supported `pihole-FTL --config` interface to set
the upstream resolvers, safe local-only listener, direct Pi-hole host record,
and the `home.rpca.uk` wildcard. Do not add a competing `dnsmasq` daemon or
legacy files under `/etc/dnsmasq.d`.

## Verify before changing clients

On the host, then from the Mac, run:

```sh
systemctl is-enabled pihole-FTL
systemctl is-active pihole-FTL
dig @192.168.1.101 pihole.home.rpca.uk +short
dig @192.168.1.101 forgejo.home.rpca.uk +short
dig @192.168.1.101 openai.com +short
curl -I http://192.168.1.101/admin/
```

Expected results are `192.168.1.101`, `192.168.1.102`, public addresses for
the external lookup, and a successful HTTP response from the last command.
After that, configure the home router's DHCP DNS server as `192.168.1.101`.
Renew a client lease or reconnect it before testing normal name resolution.

## Tailscale split DNS

After LAN DNS works, configure Tailscale's admin console with a restricted
nameserver for `home.rpca.uk` pointing to the host's **Tailscale address**
(currently `100.83.193.34`), not its LAN address. This lets tailnet devices
resolve private service names away from home without advertising the home LAN
as a subnet route. Keep MagicDNS enabled for the tailnet's own names.

Test from a Tailscale-connected device:

```sh
dig @100.83.193.34 forgejo.home.rpca.uk +short
```

## Maintenance

Run Pi-hole updates manually during normal maintenance:

```sh
ssh -t homelab 'sudo pihole -up'
```

Re-run `sudo bash ~/homelab/scripts/configure-pihole.sh` after a major Pi-hole
upgrade to ensure this homelab's DNS boundary remains explicit.
