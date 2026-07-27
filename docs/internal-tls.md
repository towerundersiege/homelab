# Internal TLS

Private application names under `home.rpca.uk` use publicly trusted Let's
Encrypt certificates. Validation uses Cloudflare DNS-01, so no application is
made public and Pi-hole remains the only DNS authority on the LAN.

## One-time Cloudflare token

In the Cloudflare dashboard, create an API token scoped to the `rpca.uk` zone:

- `Zone / DNS / Edit`
- `Zone / Zone / Read`
- Include only the `rpca.uk` zone.

Do not use a Global API Key. Keep the token private and revoke it if the Mac or
cluster credential is compromised.

After cert-manager is healthy, create the encrypted Kubernetes Secret from the
Mac:

```sh
./scripts/create-cloudflare-dns-secret.sh
git add infrastructure/certificates/cloudflare-dns-api-token.sops.yaml
git commit -m 'Add Cloudflare DNS credential'
git push
```

GitOps defines the `letsencrypt-cloudflare` `ClusterIssuer` and requests
named certificates for the private applications. DNS-01 creates short-lived
`_acme-challenge` TXT records in Cloudflare; it does not add public A/AAAA
records for private services.

Verify issued certificates and HTTPS from the Mac:

```sh
kubectl --kubeconfig ~/.config/kube/homelab.yaml get certificate -A
curl -I https://forgejo.home.rpca.uk/
curl -I https://jellyfin.home.rpca.uk/
curl -I https://navidrome.home.rpca.uk/
```
