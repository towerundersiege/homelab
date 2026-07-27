# Forgejo bootstrap

Forgejo is a private, single-replica Git forge and package registry. It will
use a retained `homelab-local` PVC on the NVMe. GitHub remains the external
bootstrap source for Flux: Forgejo is never required to recover the cluster.

The initial release uses SQLite deliberately. For one low-volume replica this
keeps the operating set small; move to PostgreSQL only if SQLite becomes a
measured bottleneck or multiple Forgejo replicas are required.

## Create the encrypted administrator secret

On the Mac, from this repository:

```sh
./scripts/create-forgejo-admin-secret.sh
git add apps/forgejo/admin.sops.yaml
git commit -m "Add Forgejo administrator secret"
git push
```

The helper prompts for a username and password locally, streams the generated
Kubernetes Secret directly through SOPS, and commits only encrypted data. Do
not paste the password into a terminal transcript, chat, or Git commit.

After the application manifests are added, Flux decrypts the Secret and the
official Forgejo Helm chart creates the administrator. Its password is set
only at initial creation and Forgejo then requires a change on first login.

## First access

After Flux reports the Forgejo Helm release ready, open:

```text
http://forgejo.home.rpca.uk
```

Sign in with the credentials supplied to the encrypted Secret, then change the
password when prompted. Registration is disabled, and the instance is private.
The initial deployment intentionally supports HTTP Git operations only; add a
private TLS route for Git-over-SSH after the base instance is validated.

## Planned access and registry

Forgejo's LAN URL will be `http://forgejo.home.rpca.uk`. Its package registry
uses the same host (for example, `forgejo.home.rpca.uk/<owner>/<image>` for
OCI images). TLS and the final Tailscale remote application path are separate
follow-up work; do not expose Forgejo publicly.

Use the GitHub repository for cluster source until Forgejo is installed,
backed up, and optionally configured as a mirror. It is not a Flux dependency.
