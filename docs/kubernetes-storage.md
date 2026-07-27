# Kubernetes storage

`homelab` is a one-node cluster. Stateful applications use the
`homelab-local` StorageClass and explicit PersistentVolumeClaims; their data is
stored on the NVMe at `/srv/operational/k3s/local-path`.

The class has `reclaimPolicy: Retain`. Deleting a PVC or Helm release does not
silently delete application data; inspect and deliberately remove the retained
PV and directory only when that is intended.

The K3s-supplied `local-path` class remains available for disposable workloads,
but application manifests must explicitly specify:

```yaml
storageClassName: homelab-local
```

Media is deliberately different. Jellyfin and Navidrome will consume a
read-only hostPath mount from `/mnt/crimson/media`; no media is copied into a
PVC on the NVMe.

## Host bootstrap

Before the first PVC, install the tracked tmpfiles rule:

```sh
ssh -t homelab 'cd ~/homelab && sudo bash scripts/configure-host-storage.sh'
```

It creates the parent directories immediately and again at every boot. Flux
reconciles the K3s local-path configuration and storage class from this
repository. Existing PVCs would remain at their old paths, but none exist on
this cluster yet.

## Backup boundary

Include `/srv/operational` in the manual external-drive backup. Retained PVs
are recovery protection, not a backup: the single NVMe can still fail.
