# GitOps bootstrap

This repository is the recovery root for the `homelab` cluster. GitHub remains
authoritative until Flux is healthy; the later private Forgejo instance mirrors
the repository and serves private OCI images and Helm charts, but is never a
bootstrap dependency.

## Layout

```text
clusters/homelab/       Flux entry point and reconciliation ordering
infrastructure/         Cluster-wide controllers, networking, certificates, storage
apps/                   Namespaces and application releases
docs/                   Canonical recovery and maintenance runbooks
```

The initial manifests create namespaces only. Add a component as its own
directory with a `kustomization.yaml`; do not put tokens, passwords, private
keys, or unencrypted Kubernetes Secrets in the repository. Encrypted SOPS
files are allowed once the age recovery process is documented.

## Bootstrap order

1. Confirm the host storage and Tailscale work after a reboot.
2. On `homelab`, run the pinned bootstrap script from a clone of this
   repository:

   ```sh
   sudo bash scripts/bootstrap-k3s-cilium.sh
   ```

   It installs K3s with Flannel, kube-proxy, ServiceLB, and Traefik disabled,
   then installs Cilium with kube-proxy replacement, Hubble, Gateway API
   support, and L2 announcements. Confirm the node becomes `Ready`.
3. On the Mac, install the local command-line clients and copy a dedicated
   kubeconfig without modifying an existing kubeconfig:

   ```sh
   brew install fluxcd/tap/flux kubectl
   mkdir -p ~/.kube
   ssh homelab 'sudo cat /etc/rancher/k3s/k3s.yaml' > ~/.kube/homelab.yaml
   chmod 600 ~/.kube/homelab.yaml
   sed -i '' 's/127.0.0.1/192.168.1.101/' ~/.kube/homelab.yaml
   kubectl --kubeconfig ~/.kube/homelab.yaml get nodes
   ```

4. Commit and push the current repository tree to `main` before bootstrapping.
   Review the existing Compose-era changes as part of that commit; Flux cannot
   reconcile files which exist only on the Mac.

5. Create a fine-grained GitHub token for the existing `towerundersiege/homelab`
   repository with Administration read/write, Contents read/write, and Metadata
   read-only access. Deploy keys are a repository-administration setting. In
   the same Mac terminal, use it only in memory and let
   Flux create a read-only SSH deploy key:

   ```sh
   read -rs GITHUB_TOKEN
   export GITHUB_TOKEN
   flux bootstrap github \
     --token-auth=false \
     --owner=towerundersiege \
     --repository=homelab \
     --branch=main \
     --path=clusters/homelab \
     --personal \
     --kubeconfig ~/.kube/homelab.yaml
   unset GITHUB_TOKEN
   ```

6. Pull the generated `clusters/homelab/flux-system/` manifests into the local
   checkout. They pin Flux's installed controllers and allow Flux to manage its
   own upgrades.

7. Verify `flux check`, `flux get sources git`, and `flux get kustomizations`.
   The `infrastructure` Kustomization must be healthy before applications are
   introduced.

Run the bootstrap from the Mac, where GitHub authentication is already
available. The GitHub token is used only to create the deploy key and is not
stored in the cluster; Flux receives the read-only SSH deploy key instead.

## Planned infrastructure order

1. SOPS age controller/key secret and recovery instructions.
2. Cilium L2/LB IPAM configuration and a Flux-managed Traefik ingress
   controller. Traefik owns the reserved LAN address `192.168.1.102` on
   `enp3s0f0`; HTTPS is added after cert-manager is available.
3. cert-manager with a narrowly scoped Cloudflare DNS token encrypted by SOPS.
4. Local-path storage policy and `/mnt/crimson` PersistentVolume definitions.
5. Cloudflare Tunnel credentials and routes, encrypted by SOPS.
6. Private applications: Forgejo, Jellyfin, Navidrome, then the lightweight
   operational tools.

Host-level Pi-hole is intentionally outside this tree: it must remain usable
when Kubernetes is unavailable. It listens on the host reservation
`192.168.1.101`; Cilium's Gateway gets `192.168.1.102`.
