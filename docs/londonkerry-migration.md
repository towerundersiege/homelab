# LondonKerry migration from Chertsey

This moves `londonkerry.com` from the Chertsey Docker Compose stack to the
homelab Kubernetes cluster. It keeps the public origin private: Cloudflare
Tunnel reaches the `wordpress` Kubernetes Service directly, with no home router
port forwarding and no public Traefik ingress.

## 1. Deploy the empty destination

On the Mac, create the encrypted database Secret, commit it with the manifests,
and let Flux reconcile:

```sh
./scripts/create-londonkerry-database-secret.sh
git add apps docs/londonkerry-migration.md scripts
git commit -m 'Add LondonKerry WordPress workload'
git push
```

Wait until both workloads are ready:

```sh
kubectl -n londonkerry get pods
```

## 2. Export and import the live site

The local `websitesdata` copy is historical; always use a fresh live export.
The export script asks for Chertsey's `sudo` password on its terminal, makes no
server-side changes, and writes a SQL dump plus `wp-content` archive locally.

```sh
./scripts/export-londonkerry-chertsey.sh
./scripts/import-londonkerry-export.sh ./londonkerry-export-YYYYMMDD-HHMMSS
```

Check the restored site privately before public cutover:

```sh
kubectl -n londonkerry port-forward service/wordpress 8080:80
```

Open `http://localhost:8080` and confirm the home page, media, login, and an
admin update. Do not use the public hostname for this test.

## 3. Short write freeze and final cutover

For a consistent final import, arrange a short editing freeze, repeat export
and import, then add this **Public Hostname** to the existing `homelab` tunnel
in Cloudflare Zero Trust:

| Hostname | Service |
| --- | --- |
| `londonkerry.com` | `http://wordpress.londonkerry.svc.cluster.local:80` |

Cloudflare manages the proxied DNS record and public TLS. Test from outside the
LAN/Tailscale using `curl -I https://londonkerry.com/`, log in, and submit a
non-destructive content edit. Keep Chertsey running for at least 48 hours after
that verification. Only then cancel the Hetzner VPS and retain an offline copy
of the final export.

If a route must be reversed, remove the tunnel public hostname; Chertsey has
not been changed and can continue serving the domain.
