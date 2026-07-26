#!/usr/bin/env bash
# Configure the small host-level Pi-hole DNS boundary for homelab.
#
# Run only after the official Pi-hole installer has completed successfully:
#   sudo bash scripts/configure-pihole.sh
set -euo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Run this script with sudo." >&2
  exit 1
fi

if ! command -v pihole-FTL >/dev/null 2>&1; then
  echo "Pi-hole is not installed. Run the official installer first." >&2
  exit 1
fi

# Do not use the host's /etc/resolv.conf as an upstream: Tailscale manages it
# for MagicDNS. The public resolvers keep Pi-hole independent of that detail.
pihole-FTL --config dns.upstreams '["1.1.1.1","1.0.0.1"]'

# Tailscale nodes use a /32 address, so Pi-hole's LOCAL mode rejects remote
# tailnet queries even though tailscale0 exists. ALL is required for this
# LAN-plus-tailnet resolver. It is safe only because this host has no WAN DNS
# port-forward: the router/LAN and authenticated tailnet remain the boundary.
pihole-FTL --config dns.listeningMode "ALL"

# Pi-hole itself stays outside Kubernetes on the host IP. The wildcard mapping
# is deliberately limited to the private homelab DNS suffix; Cilium receives
# all application traffic on the separately reserved LoadBalancer IP.
pihole-FTL --config dns.hostRecord "pihole,pihole.home.rpca.uk,192.168.1.101"
pihole-FTL --config misc.dnsmasq_lines '["address=/home.rpca.uk/192.168.1.102"]'

systemctl enable --now pihole-FTL
systemctl restart pihole-FTL

echo "Pi-hole configured. Verify with:"
echo "  dig @192.168.1.101 pihole.home.rpca.uk +short"
echo "  dig @192.168.1.101 example.home.rpca.uk +short"
