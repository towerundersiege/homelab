# Public media through Cloudflare Tunnel

Only Jellyfin and Navidrome are public. Forgejo, Pi-hole, Kubernetes, and all
`*.home.rpca.uk` services remain private to the LAN or Tailscale.

The tunnel is remotely managed by Cloudflare. The only cluster credential is
its scoped tunnel token, encrypted with SOPS; public hostname routing remains
in the Cloudflare dashboard so DNS records and edge policy are visible in one
place.

## Create the tunnel

1. In Cloudflare, go to **Networking > Tunnels > Create tunnel**.
2. Name it `homelab-media` and select **Docker** as the connector type.
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

Verify from a network outside the LAN/Tailscale:

```sh
curl -I https://media.rpca.uk/
curl -I https://music.rpca.uk/
```

To remove public exposure, delete the published application routes first and
then remove the encrypted token manifest from Git. Rotate the tunnel token in
Cloudflare if it is ever exposed.
