# SOPS age recovery key

Flux decrypts application secrets with one age private key stored in the
`flux-system/sops-age` Kubernetes Secret. The matching public age recipient is
safe to commit in the repository's `.sops.yaml`; the private key is not.

This is an intentional bootstrap exception: Flux cannot decrypt the key that
allows it to decrypt secrets. Create it once from the Mac, then keep two
offline copies of the private key (for example, an encrypted external backup
and a password manager attachment).

## Create and back up the key

On the Mac:

```sh
brew install age sops
umask 077
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/homelab.agekey
age-keygen -y ~/.config/sops/age/homelab.agekey
```

The final command prints the public recipient (`age1...`). It is safe to share
with this repository and with Codex. Do not share, commit, or paste the
contents of `homelab.agekey`.

Make two encrypted/offline backups before continuing. Losing both the private
key and the cluster's `sops-age` Secret makes existing encrypted secrets
unrecoverable.

## Install the cluster decryption secret

After the backups exist, apply the private key to the cluster from the Mac.
This command is safe to rerun and does not place the key in Git:

```sh
kubectl --kubeconfig ~/.config/kube/homelab.yaml \
  -n flux-system create secret generic sops-age \
  --from-file=age.agekey="$HOME/.config/sops/age/homelab.agekey" \
  --dry-run=client -o yaml | \
kubectl --kubeconfig ~/.config/kube/homelab.yaml apply -f -

kubectl --kubeconfig ~/.config/kube/homelab.yaml \
  -n flux-system get secret sops-age
```

The `age.agekey` filename is required: Flux detects an age key from the file
extension.

## Repository setup (next step)

The root [`.sops.yaml`](../.sops.yaml) contains the public recipient and
creation rules for Kubernetes `data` and `stringData` fields. Both Flux
`infrastructure` and `apps` Kustomizations use `sops-age` for decryption. Only
after those changes are committed and reconciled should encrypted Cloudflare,
Pi-hole, Forgejo, or application secrets be committed.

To create a new encrypted Kubernetes secret after SOPS is configured:

```sh
kubectl -n example create secret generic example-secret \
  --from-literal=value=replace-me \
  --dry-run=client -o yaml > secret.sops.yaml
sops --encrypt --in-place secret.sops.yaml
```

Do not apply `secret.sops.yaml` with `kubectl`; Flux decrypts and applies it
during reconciliation.
