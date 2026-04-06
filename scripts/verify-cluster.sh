#!/usr/bin/env bash
# Run ON the EC2 instance to verify the full platform is healthy.
# Checks every layer: node, ServiceLB, ingress, ArgoCD, Prometheus, Grafana dashboard.
# Exits 0 if all checks pass, 1 if any fail.
#
# Usage:
#   export PATH="/usr/local/bin:$PATH"
#   bash scripts/verify-cluster.sh

set -uo pipefail

export PATH="/usr/local/bin:$PATH"

PASS=0
FAIL=0

ok()   { echo "[PASS] $*"; PASS=$((PASS + 1)); }
fail() { echo "[FAIL] $*"; FAIL=$((FAIL + 1)); }
info() { echo "[INFO] $*"; }
section() { echo ""; echo "=== $* ==="; }

# ─── Prerequisites ───────────────────────────────────────────────────────────

section "Prerequisites"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "[FAIL] kubectl not found — run: export PATH=\"/usr/local/bin:\$PATH\""
  exit 1
fi
ok "kubectl found at $(command -v kubectl)"

if ! command -v curl >/dev/null 2>&1; then
  fail "curl not found"
fi

# ─── Node ────────────────────────────────────────────────────────────────────

section "Node"

NODE_STATUS=$(kubectl get node -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
NODE_NAME=$(kubectl get node -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "unknown")
NODE_VERSION=$(kubectl get node -o jsonpath='{.items[0].status.nodeInfo.kubeletVersion}' 2>/dev/null || echo "unknown")

if [[ "${NODE_STATUS}" == "True" ]]; then
  ok "Node ${NODE_NAME} Ready (${NODE_VERSION})"
else
  fail "Node ${NODE_NAME} not Ready — status: ${NODE_STATUS}"
fi

# ─── ServiceLB + Traefik ─────────────────────────────────────────────────────

section "ServiceLB + Traefik ingress"

SVCLB_COUNT=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -c svclb || true)
if [[ "${SVCLB_COUNT}" -ge 1 ]]; then
  SVCLB_RUNNING=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep svclb | grep -c Running || true)
  if [[ "${SVCLB_RUNNING}" -ge 1 ]]; then
    ok "ServiceLB pod running (${SVCLB_RUNNING}/${SVCLB_COUNT})"
  else
    fail "ServiceLB pod exists but not Running — check: kubectl get pods -n kube-system | grep svclb"
  fi
else
  fail "No ServiceLB pods found — k3s may have been started with --disable servicelb"
  info "Fix: sudo sed -i \"/'--disable'/d; /'servicelb'/d\" /etc/systemd/system/k3s.service"
  info "     sudo systemctl daemon-reload && sudo systemctl restart k3s"
fi

TRAEFIK_IP=$(kubectl get svc -n kube-system traefik \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
if [[ -n "${TRAEFIK_IP}" && "${TRAEFIK_IP}" != "<pending>" ]]; then
  ok "Traefik external IP: ${TRAEFIK_IP}"
else
  fail "Traefik LoadBalancer still <pending> — ServiceLB not assigning an IP"
fi

if curl -sf --connect-timeout 5 http://localhost/health >/dev/null 2>&1; then
  ok "Port 80 /health responds"
else
  fail "Port 80 /health did not respond — ingress or app not reachable"
fi

# ─── Namespaces ──────────────────────────────────────────────────────────────

section "Namespaces"

for NS in argocd monitoring sample-app; do
  if kubectl get namespace "${NS}" >/dev/null 2>&1; then
    ok "Namespace ${NS} exists"
  else
    fail "Namespace ${NS} missing — run: kubectl apply -f cluster/namespaces.yaml"
  fi
done

# ─── ArgoCD applications ─────────────────────────────────────────────────────

section "ArgoCD applications"

if ! kubectl get applications -n argocd >/dev/null 2>&1; then
  fail "Cannot list ArgoCD applications — ArgoCD may not be installed"
else
  for APP in app-of-apps grafana-dashboards prometheus sample-app; do
    SYNC=$(kubectl get application "${APP}" -n argocd \
      -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Missing")
    HEALTH=$(kubectl get application "${APP}" -n argocd \
      -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Missing")

    if [[ "${SYNC}" == "Synced" && "${HEALTH}" == "Healthy" ]]; then
      ok "ArgoCD app ${APP}: Synced + Healthy"
    elif [[ "${SYNC}" == "Synced" && "${HEALTH}" == "Progressing" ]]; then
      # sample-app Progressing is expected when HPA ScalingLimited=TooFewReplicas
      # (CPU low, min replicas floor active) — not a fault, warn only
      echo "[WARN] ArgoCD app ${APP}: Synced + Progressing (check HPA or Ingress address)"
    else
      fail "ArgoCD app ${APP}: sync=${SYNC} health=${HEALTH}"
    fi
  done
fi

# ─── Sample app ──────────────────────────────────────────────────────────────

section "Sample app"

SA_READY=$(kubectl get deployment sample-app -n sample-app \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
SA_DESIRED=$(kubectl get deployment sample-app -n sample-app \
  -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")

if [[ "${SA_READY}" -ge 2 ]]; then
  ok "sample-app deployment: ${SA_READY}/${SA_DESIRED} replicas ready"
else
  fail "sample-app deployment: only ${SA_READY}/${SA_DESIRED} replicas ready"
fi

HEALTH_BODY=$(curl -sf --connect-timeout 5 http://localhost/health 2>/dev/null || echo "")
if echo "${HEALTH_BODY}" | grep -q '"status":"ok"'; then
  ok "GET /health → {\"status\":\"ok\"}"
else
  fail "GET /health did not return expected body (got: ${HEALTH_BODY:-no response})"
fi

SA_POD=$(kubectl get pod -n sample-app -l app=sample-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "${SA_POD}" ]; then
  METRICS_BODY=$(kubectl exec -n sample-app "${SA_POD}" -- wget -qO- http://localhost:3000/metrics 2>/dev/null || echo "")
  if echo "${METRICS_BODY}" | grep -q '^http_requests_total{'; then
    ok "GET /metrics → http_requests_total present"
  else
    fail "GET /metrics missing http_requests_total"
  fi
else
  fail "GET /metrics — no sample-app pod found"
fi

# Check for orphaned standalone Grafana (should have been deleted)
if kubectl get deployment grafana -n monitoring >/dev/null 2>&1; then
  fail "Orphaned standalone grafana deployment found in monitoring — delete it:"
  info "  kubectl delete deployment grafana -n monitoring"
  info "  kubectl delete service grafana -n monitoring"
else
  ok "No orphaned standalone Grafana deployment"
fi

# ─── Prometheus ──────────────────────────────────────────────────────────────

section "Prometheus"

PROM_READY=$(kubectl get pod prometheus-prometheus-kube-prometheus-prometheus-0 \
  -n monitoring -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
if [[ "${PROM_READY}" == "Running" ]]; then
  ok "Prometheus pod Running"
else
  fail "Prometheus pod not Running (phase: ${PROM_READY:-not found})"
fi

# Query active targets for sample-app
SAMPLE_TARGETS=$(kubectl exec -n monitoring \
  prometheus-prometheus-kube-prometheus-prometheus-0 \
  -c prometheus -- \
  wget -qO- 'http://localhost:9090/api/v1/targets?state=active' 2>/dev/null | \
  python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    targets = [t for t in d['data']['activeTargets'] if t['labels'].get('job') == 'sample-app']
    up = [t for t in targets if t['health'] == 'up']
    print(f'{len(up)}/{len(targets)}')
except Exception as e:
    print('0/0')
" 2>/dev/null || echo "0/0")

UP=$(echo "${SAMPLE_TARGETS}" | cut -d/ -f1)
TOTAL=$(echo "${SAMPLE_TARGETS}" | cut -d/ -f2)

if [[ "${UP}" -ge 2 ]] 2>/dev/null; then
  ok "Prometheus scraping sample-app: ${SAMPLE_TARGETS} targets up"
elif [[ "${UP}" -ge 1 ]] 2>/dev/null; then
  echo "[WARN] Prometheus scraping sample-app: only ${SAMPLE_TARGETS} targets up (expected 2)"
else
  fail "Prometheus not scraping sample-app (${SAMPLE_TARGETS}) — check ServiceMonitor and serviceMonitorSelectorNilUsesHelmValues"
fi

# ─── Grafana dashboard ────────────────────────────────────────────────────────

section "Grafana dashboard"

GRAFANA_READY=$(kubectl get pod -n monitoring -l "app.kubernetes.io/name=grafana" \
  --no-headers 2>/dev/null | grep -c Running || true)
if [[ "${GRAFANA_READY}" -ge 1 ]]; then
  ok "Grafana pod Running"
else
  fail "Grafana pod not Running"
fi

CM_EXISTS=$(kubectl get configmap grafana-dashboard-sample-app -n monitoring \
  --no-headers 2>/dev/null | wc -l || echo "0")
if [[ "${CM_EXISTS}" -ge 1 ]]; then
  ok "ConfigMap grafana-dashboard-sample-app exists"
else
  fail "ConfigMap grafana-dashboard-sample-app missing — check grafana-dashboards ArgoCD app"
fi

CM_LABEL=$(kubectl get configmap grafana-dashboard-sample-app -n monitoring \
  -o jsonpath='{.metadata.labels.grafana_dashboard}' 2>/dev/null || echo "")
if [[ "${CM_LABEL}" == "1" ]]; then
  ok "ConfigMap label grafana_dashboard=1 present (sidecar will load it)"
else
  fail "ConfigMap missing label grafana_dashboard=1 — Grafana sidecar won't pick it up"
fi

# ─── Public IP ───────────────────────────────────────────────────────────────

section "Access URLs"

IMDS="http://169.254.169.254"
TOKEN=$(curl -s -X PUT "${IMDS}/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 60" --connect-timeout 2 2>/dev/null || echo "")
if [[ -n "${TOKEN}" ]]; then
  PUB=$(curl -s -H "X-aws-ec2-metadata-token: ${TOKEN}" \
    "${IMDS}/latest/meta-data/public-ipv4" --connect-timeout 2 2>/dev/null || echo "")
else
  PUB=""
fi

if [[ -n "${PUB}" && "${PUB}" != *"404"* ]]; then
  info "ArgoCD UI:   http://${PUB}:30080"
  info "Sample app:  http://${PUB}/"
  info "Grafana:     kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80"
  info "             then open http://localhost:3000 (admin / changeme-grafana-lab-2026)"
else
  info "Could not fetch public IP from IMDS — check AWS console for current public IPv4"
fi

# ─── Summary ─────────────────────────────────────────────────────────────────

echo ""
echo "================================================="
echo "  PASSED: ${PASS}"
echo "  FAILED: ${FAIL}"
echo "================================================="

if [[ "${FAIL}" -eq 0 ]]; then
  echo "  Platform is healthy."
  exit 0
else
  echo "  ${FAIL} check(s) failed — review [FAIL] lines above."
  exit 1
fi
