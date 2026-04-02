#!/usr/bin/env bash
# install-argocd.sh
# Installs ArgoCD into the argocd namespace and exposes it on NodePort 30080.
# Idempotent — safe to re-run.
# Run after install-k3s.sh.
# Usage: bash install-argocd.sh

set -euo pipefail

ARGOCD_VERSION="v2.13.3"
ARGOCD_NAMESPACE="argocd"
ARGOCD_NODEPORT="30080"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }

echo ""
echo "=================================="
echo "  ArgoCD Install — ${ARGOCD_VERSION} "
echo "=================================="
echo ""

# ─── Preflight ─────────────────────────────────────────────────────────────────
kubectl version --client >/dev/null 2>&1 || { echo "kubectl not found. Run install-k3s.sh first."; exit 1; }

# ─── Idempotency check ─────────────────────────────────────────────────────────
if kubectl get namespace "$ARGOCD_NAMESPACE" >/dev/null 2>&1; then
  info "ArgoCD namespace already exists — checking if server is running..."
  if kubectl get deployment argocd-server -n "$ARGOCD_NAMESPACE" >/dev/null 2>&1; then
    success "ArgoCD is already installed — skipping."
    echo ""
    info "Admin password:"
    kubectl get secret argocd-initial-admin-secret \
      -n "$ARGOCD_NAMESPACE" \
      -o jsonpath='{.data.password}' | base64 -d
    echo ""
    exit 0
  fi
fi

# ─── Create namespace ──────────────────────────────────────────────────────────
info "Creating namespace ${ARGOCD_NAMESPACE}..."
kubectl create namespace "$ARGOCD_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# ─── Install ArgoCD ────────────────────────────────────────────────────────────
info "Installing ArgoCD ${ARGOCD_VERSION}..."
kubectl apply -n "$ARGOCD_NAMESPACE" \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

# ─── Wait for ArgoCD server to be ready ────────────────────────────────────────
info "Waiting for argocd-server deployment to be ready (up to 3 minutes)..."
kubectl rollout status deployment/argocd-server \
  -n "$ARGOCD_NAMESPACE" \
  --timeout=180s

# ─── Expose ArgoCD on NodePort 30080 ───────────────────────────────────────────
info "Patching argocd-server service to NodePort ${ARGOCD_NODEPORT}..."
kubectl patch svc argocd-server \
  -n "$ARGOCD_NAMESPACE" \
  -p "{\"spec\":{\"type\":\"NodePort\",\"ports\":[{\"port\":80,\"targetPort\":8080,\"nodePort\":${ARGOCD_NODEPORT},\"name\":\"http\"}]}}"

# ─── Print initial admin password ──────────────────────────────────────────────
echo ""
success "ArgoCD install complete!"
echo ""
echo "  URL      : http://<public-ip>:${ARGOCD_NODEPORT}"
echo "  Username : admin"
echo -n "  Password : "
kubectl get secret argocd-initial-admin-secret \
  -n "$ARGOCD_NAMESPACE" \
  -o jsonpath='{.data.password}' | base64 -d
echo ""
echo ""
echo "  Change the password after first login:"
echo "  argocd account update-password"
echo ""
