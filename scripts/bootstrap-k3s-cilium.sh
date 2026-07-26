#!/usr/bin/env bash
# Bootstrap the single-node K3s control plane and its Cilium CNI.
# Run on homelab as: sudo bash scripts/bootstrap-k3s-cilium.sh

set -euo pipefail

readonly K3S_VERSION='v1.36.1+k3s1'
readonly CILIUM_VERSION='1.19.6'
readonly CILIUM_CLI_VERSION='v0.19.2'
readonly KUBECONFIG_PATH='/etc/rancher/k3s/k3s.yaml'

if [[ ${EUID} -ne 0 ]]; then
  echo 'Run this script as root: sudo bash scripts/bootstrap-k3s-cilium.sh' >&2
  exit 1
fi

if [[ $(uname -m) != 'x86_64' ]]; then
  echo 'This initial bootstrap is pinned for the amd64 ThinkCentre host.' >&2
  exit 1
fi

if ! command -v k3s >/dev/null 2>&1; then
  echo "Installing K3s ${K3S_VERSION} with its default CNI, kube-proxy, ServiceLB, and Traefik disabled..."
  curl --fail --show-error --silent https://get.k3s.io | \
    INSTALL_K3S_VERSION="${K3S_VERSION}" \
    INSTALL_K3S_EXEC='server --flannel-backend=none --disable-network-policy --disable-kube-proxy --disable=traefik --disable=servicelb' \
    sh -
else
  echo "K3s already installed: $(k3s --version | head -n1)"
fi

install_cilium_cli() {
  local archive checksum_file tempdir
  archive="cilium-linux-amd64.tar.gz"
  checksum_file="${archive}.sha256sum"
  tempdir=$(mktemp -d)
  trap 'rm -rf "${tempdir}"' RETURN

  curl --fail --show-error --silent --location \
    -o "${tempdir}/${archive}" \
    "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/${archive}"
  curl --fail --show-error --silent --location \
    -o "${tempdir}/${checksum_file}" \
    "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/${checksum_file}"
  (
    cd "${tempdir}"
    sha256sum --check "${checksum_file}"
    tar -xzf "${archive}"
    install -m 0755 cilium /usr/local/bin/cilium
  )
}

if ! command -v cilium >/dev/null 2>&1; then
  echo "Installing Cilium CLI ${CILIUM_CLI_VERSION}..."
  install_cilium_cli
fi

export KUBECONFIG="${KUBECONFIG_PATH}"

echo 'Waiting for the K3s API server...'
until k3s kubectl get --raw=/readyz >/dev/null 2>&1; do
  sleep 2
done

if ! kubectl -n kube-system get daemonset cilium >/dev/null 2>&1; then
  echo "Installing Cilium ${CILIUM_VERSION}..."
  cilium install --version "${CILIUM_VERSION}" \
    --set kubeProxyReplacement=true \
    --set k8sServiceHost=127.0.0.1 \
    --set k8sServicePort=6443 \
    --set ipam.operator.clusterPoolIPv4PodCIDRList=10.42.0.0/16 \
    --set operator.replicas=1 \
    --set bpf.hostLegacyRouting=true \
    --set hubble.relay.enabled=true \
    --set hubble.ui.enabled=true \
    --set gatewayAPI.enabled=true \
    --set gatewayAPI.gatewayClass.create=false \
    --set l2announcements.enabled=true
else
  echo 'Cilium is already installed; not changing its Helm values.'
fi

cilium status --wait
k3s kubectl get nodes -o wide

cat <<'EOF'

K3s and Cilium are healthy. Do not install applications directly with kubectl.
Next: run the Flux bootstrap from the Mac as documented in docs/gitops-bootstrap.md.
EOF
