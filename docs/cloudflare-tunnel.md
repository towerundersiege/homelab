# Public media through Cloudflare Tunnel

Only Jellyfin and Navidrome are public. Forgejo, Pi-hole, Kubernetes, and all
`*.home.rpca.uk` services remain private to the LAN or Tailscale.

The tunnel is remotely managed by Cloudflare. The only cluster credential is
its scoped tunnel token, encrypted with SOPS; public hostname routing remains
in the Cloudflare dashboard so DNS records and edge policy are visible in one
place.

## Create the tunnel

1. In Cloudflare, go to **Networking > Tunnels > Create tunnel**.
2. Name it `homelab` and select **Docker** as the connector type. The tunnel is
   a shared outward connector; its routes—not its name—define which services
   are public.
3. Copy only the token from the generated command (the value beginning
   `eyJ...`). Do not run the command and do not paste the token into chat or a
   shell history.
4. From the repository on the Mac, create the encrypted Secret:

   ```sh
   ./scripts/create-cloudflared-token-secret.sh
   git add infrastructure/cloudflare-tunnel/cloudflared-token.sops.yaml
   git commit -m 'Add Cloudflare Tunnel credential'
   git push
   ```

5. Ask Codex to enable the staged `cloudflare-tunnel` infrastructure component.
   It is intentionally not enabled before the encrypted Secret exists, so Flux
   can never reconcile a missing or placeholder tunnel credential.

6. Confirm the connector becomes healthy:

   ```sh
   kubectl --kubeconfig ~/.config/kube/homelab.yaml \
     -n cloudflare-tunnel get pods
   ```

## Publish exactly two applications

In that tunnel's **Routes**, add these published applications. Cloudflare
creates the proxied DNS records automatically.

| Public hostname | Service URL |
| --- | --- |
| `media.rpca.uk` | `http://jellyfin.media.svc.cluster.local:8096` |
| `music.rpca.uk` | `http://navidrome.media.svc.cluster.local:4533` |

These origins are Kubernetes Services reached only by the cloudflared pod;
they do not expose new LAN ports. Cloudflare provides public HTTPS at the edge.
The host network blocks outbound QUIC, so the connector is intentionally pinned
to Cloudflare Tunnel's supported HTTP/2 transport over TCP instead.

## Required edge policy

Keep these rules scoped exactly to the two public hostnames. Do not apply them
to `*.rpca.uk`: the private `*.home.rpca.uk` names are resolved by Pi-hole and
never pass through Cloudflare Tunnel.

### Bypass Cloudflare's cache

In **Rules > Cache Rules**, create a rule named `Bypass cache for public media`:

```text
http.host in {"media.rpca.uk" "music.rpca.uk"}
```

Set its action to **Bypass cache**. This prevents Cloudflare from retaining
Jellyfin or Navidrome responses and media chunks at the edge.

### Restrict public access to the UK

In **Security > WAF > Custom rules**, create a rule named
`Public media: UK only`:

```text
(http.host in {"media.rpca.uk" "music.rpca.uk"}) and (ip.geoip.country ne "GB")
```

Set its action to **Block**. This reduces the public bot surface, but does not
block UK-based clients or bots. It will also block legitimate use while outside
the UK or when using a VPN with a non-UK exit node; use the private
`*.home.rpca.uk` route through Tailscale in that situation.

Verify from a network outside the LAN/Tailscale:

```sh
curl -I https://media.rpca.uk/
curl -I https://music.rpca.uk/
```

To remove public exposure, delete the published application routes first and
then remove the encrypted token manifest from Git. Rotate the tunnel token in
Cloudflare if it is ever exposed.
