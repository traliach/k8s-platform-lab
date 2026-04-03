#!/usr/bin/env bash
# install-k3s.sh
# Idempotent k3s install script for Amazon Linux 2023.
# Run as ec2-user via SSH. Safe to re-run — skips install if k3s is already running.
# Usage: bash install-k3s.sh

set -euo pipefail

K3S_VERSION="v1.31.4+k3s1"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }

echo ""
echo "=============================="
echo "  k3s Install — ${K3S_VERSION} "
echo "=============================="
echo ""

# ─── Idempotency check ─────────────────────────────────────────────────────────
if systemctl is-active --quiet k3s 2>/dev/null; then
  success "k3s is already running — skipping install."
  kubectl get nodes
  exit 0
fi

# ─── Install k3s ───────────────────────────────────────────────────────────────
info "Installing k3s ${K3S_VERSION}..."

curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="${K3S_VERSION}" sh -s - \
  --write-kubeconfig-mode 644 \
  --node-name k8s-platform-lab-node

# ─── Wait for node to be ready ─────────────────────────────────────────────────
info "Waiting for node to become Ready..."
for i in $(seq 1 30); do
  STATUS=$(kubectl get nodes --no-headers 2>/dev/null | awk '{print $2}' || echo "NotReady")
  if [[ "$STATUS" == "Ready" ]]; then
    success "Node is Ready."
    break
  fi
  echo "  Attempt $i/30 — status: ${STATUS}. Retrying in 5s..."
  sleep 5
done

# ─── Set up kubeconfig for ec2-user ────────────────────────────────────────────
info "Configuring kubeconfig for ec2-user..."
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown "$(id -u):$(id -g)" ~/.kube/config
chmod 600 ~/.kube/config

# ─── Verify ────────────────────────────────────────────────────────────────────
echo ""
success "k3s install complete!"
echo ""
kubectl get nodes -o wide
echo ""
kubectl get pods -A
