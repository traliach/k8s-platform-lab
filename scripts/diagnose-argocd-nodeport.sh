#!/usr/bin/env bash
# Run ON the EC2 instance (after k3s + Argo CD install) to debug "browser cannot connect to :30080".
# Does not fix anything — reports what to verify in AWS and on the node.

set -euo pipefail

export PATH="/usr/local/bin:$PATH"

echo "=== Argo CD NodePort diagnostics ==="
echo ""

fail() { echo "[FAIL] $*"; }
ok()   { echo "[OK]   $*"; }
warn() { echo "[WARN] $*"; }

# --- kubectl / cluster ---
if ! command -v kubectl >/dev/null 2>&1; then
  fail "kubectl not found. export PATH=\"/usr/local/bin:\$PATH\""
  exit 1
fi
ok "kubectl: $(command -v kubectl)"

if ! kubectl get ns argocd >/dev/null 2>&1; then
  fail "namespace argocd does not exist"
  exit 1
fi
ok "namespace argocd exists"

if ! kubectl get svc -n argocd argocd-server >/dev/null 2>&1; then
  fail "Service argocd-server not found in argocd"
  exit 1
fi

echo ""
echo "--- argocd-server Service (expect TYPE=NodePort, port 30080) ---"
kubectl get svc -n argocd argocd-server -o wide
NP=$(kubectl get svc -n argocd argocd-server -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}' 2>/dev/null || true)
if [[ -z "${NP}" ]]; then
  NP=$(kubectl get svc -n argocd argocd-server -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || true)
fi
if [[ "${NP}" == "30080" ]]; then
  ok "NodePort is 30080"
else
  warn "NodePort is '${NP:-empty}' (install script expects 30080; UI URL must match actual nodePort)"
fi

echo ""
echo "--- argocd-server pods ---"
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server 2>/dev/null || kubectl get pods -n argocd | grep argocd-server || true

echo ""
echo "--- Local HTTP check (on the node itself) ---"
if curl -sI --connect-timeout 5 "http://127.0.0.1:${NP:-30080}" 2>/dev/null | head -1 | grep -q HTTP; then
  ok "curl http://127.0.0.1:${NP:-30080} returned HTTP headers — NodePort works on loopback"
else
  fail "curl to 127.0.0.1:${NP:-30080} failed — Argo CD UI not reachable on this node (pods/svc/NodePort)"
fi

echo ""
echo "--- Listen sockets (30080 or nodePort) ---"
if command -v ss >/dev/null 2>&1; then
  ss -tlnp 2>/dev/null | grep -E ':30080\b' || ss -tlnp 2>/dev/null | grep -E ":${NP}\b" || warn "ss: no listener on 30080 (kube-proxy may still forward; trust curl above)"
elif command -v netstat >/dev/null 2>&1; then
  netstat -tlnp 2>/dev/null | grep 30080 || true
else
  warn "ss/netstat not available"
fi

echo ""
echo "--- This instance public IPv4 (IMDS) — use THIS in browser, not an old IP ---"
IMDS="http://169.254.169.254"
if TOKEN=$(curl -s -X PUT "${IMDS}/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" --connect-timeout 2); then
  PUB=$(curl -s -H "X-aws-ec2-metadata-token: ${TOKEN}" "${IMDS}/latest/meta-data/public-ipv4" --connect-timeout 2) || PUB=""
  if [[ -n "${PUB}" && "${PUB}" != *"404"* ]]; then
    ok "Public IPv4 from metadata: ${PUB}"
    echo "    Try: http://${PUB}:${NP:-30080}"
  else
    warn "No public IPv4 from IMDS (subnet may not map public IP, or IMDS v2 blocked)"
  fi
else
  warn "Could not reach EC2 IMDS (not on EC2?)"
fi

echo ""
echo "--- Private IP (for reference) ---"
hostname -I 2>/dev/null | awk '{print $1}' || true

echo ""
echo "=== Manual checks outside this script ==="
echo "1) AWS EC2 → Instance → Public IPv4 must match the URL you open in the browser."
echo "   Stopped/started instances get a NEW public IP unless you use an Elastic IP."
echo "2) Security group INBOUND: TCP ${NP:-30080} from your IP (or 0.0.0.0/0 for lab)."
echo "   Repo Terraform: infra/networking.tf ingress on port 30080 — terraform apply if rule missing."
echo "3) Corporate/VPN/firewall may block non-standard ports — try another network or phone hotspot."
echo "4) Argo CD install: cluster/bootstrap/install-argocd.sh patches NodePort 30080."
echo "=== Done ==="
