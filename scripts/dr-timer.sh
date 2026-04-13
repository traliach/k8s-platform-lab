#!/usr/bin/env bash
# dr-timer.sh
# Tracks wall-clock time for each disaster recovery step.
# Run from the repo root on your LOCAL machine (not the EC2 instance).
#
# Usage:
#   export AWS_PROFILE=terraform-deployer
#   bash scripts/dr-timer.sh
#
# At the end it prints a summary + the exact markdown row to paste into
# docs/disaster-recovery.md.

set -euo pipefail

# ─── Colours ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
header()  { echo -e "\n${BOLD}${YELLOW}══════════════════════════════════════${NC}"; echo -e "${BOLD}${YELLOW}  $*${NC}"; echo -e "${BOLD}${YELLOW}══════════════════════════════════════${NC}\n"; }

# ─── Timer helpers ─────────────────────────────────────────────────────────────
declare -A STEP_START
declare -A STEP_END
declare -a STEP_ORDER

now_epoch() { date +%s; }

step_start() {
  local name="$1"
  STEP_ORDER+=("$name")
  STEP_START["$name"]=$(now_epoch)
  info "Started: ${name}"
}

step_end() {
  local name="$1"
  STEP_END["$name"]=$(now_epoch)
  local elapsed=$(( STEP_END["$name"] - STEP_START["$name"] ))
  success "Done: ${name} — ${elapsed}s"
}

elapsed_fmt() {
  local secs="$1"
  printf "%dm %02ds" $(( secs / 60 )) $(( secs % 60 ))
}

# ─── Overall start ─────────────────────────────────────────────────────────────
DR_START=$(now_epoch)
DR_DATE=$(date '+%Y-%m-%d')
DR_START_TIME=$(date '+%H:%M:%S')

header "DR Recovery Timer — ${DR_DATE} ${DR_START_TIME}"
info "AWS_PROFILE = ${AWS_PROFILE:-not set — export AWS_PROFILE=terraform-deployer}"
echo ""

# ─── Preflight check ───────────────────────────────────────────────────────────
if [[ -z "${AWS_PROFILE:-}" ]]; then
  echo -e "${YELLOW}[WARN]${NC}  AWS_PROFILE is not set. Run: export AWS_PROFILE=terraform-deployer"
fi

if [[ -z "${TF_VAR_public_key:-}" ]]; then
  echo -e "${YELLOW}[WARN]${NC}  TF_VAR_public_key is not set. Run: export TF_VAR_public_key=\"\$(cat ~/.ssh/k8s-platform-lab-key.pub)\""
fi

# ─── Step 1: Terraform apply ───────────────────────────────────────────────────
header "Step 1 — Reprovision VM (terraform apply)"
step_start "Step 1: Terraform apply"

cd infra
terraform init -upgrade -reconfigure
terraform plan -out=tfplan
terraform apply tfplan

PUBLIC_IP=$(terraform output -raw public_ip)
SSH_CMD=$(terraform output -raw ssh_command)
cd ..

step_end "Step 1: Terraform apply"

echo ""
info "New public IP : ${PUBLIC_IP}"
info "SSH command   : ${SSH_CMD}"
info "Waiting 60s for EC2 instance to pass health checks..."
sleep 60

# ─── Step 2: Bootstrap k3s ─────────────────────────────────────────────────────
header "Step 2 — Bootstrap k3s"
step_start "Step 2: k3s install"

scp -i ~/.ssh/k8s-platform-lab-key -o StrictHostKeyChecking=no \
  cluster/bootstrap/install-k3s.sh \
  cluster/bootstrap/install-argocd.sh \
  ec2-user@"${PUBLIC_IP}":~

ssh -i ~/.ssh/k8s-platform-lab-key -o StrictHostKeyChecking=no \
  ec2-user@"${PUBLIC_IP}" \
  "bash install-k3s.sh"

step_end "Step 2: k3s install"

# ─── Step 3: Install ArgoCD ────────────────────────────────────────────────────
header "Step 3 — Install ArgoCD"
step_start "Step 3: ArgoCD install"

ssh -i ~/.ssh/k8s-platform-lab-key -o StrictHostKeyChecking=no \
  ec2-user@"${PUBLIC_IP}" \
  "bash install-argocd.sh"

step_end "Step 3: ArgoCD install"

# ─── Step 4: Apply App of Apps ─────────────────────────────────────────────────
header "Step 4 — Apply App of Apps"
step_start "Step 4: App of Apps"

scp -i ~/.ssh/k8s-platform-lab-key -o StrictHostKeyChecking=no \
  ec2-user@"${PUBLIC_IP}":~/.kube/config \
  ~/.kube/k8s-platform-lab-config

# Fix server address in kubeconfig to use public IP
sed -i "s|127.0.0.1|${PUBLIC_IP}|g" ~/.kube/k8s-platform-lab-config
export KUBECONFIG=~/.kube/k8s-platform-lab-config

kubectl apply -f gitops/argocd/app-of-apps.yaml

info "Waiting for ArgoCD apps to sync (up to 5 min)..."
for i in $(seq 1 30); do
  SYNCED=$(kubectl get applications -n argocd --no-headers 2>/dev/null \
    | awk '{print $2}' | grep -c "Synced" || true)
  TOTAL=$(kubectl get applications -n argocd --no-headers 2>/dev/null \
    | wc -l | tr -d ' ' || echo 0)
  if [[ "$SYNCED" -ge "$TOTAL" && "$TOTAL" -gt 0 ]]; then
    success "All ${TOTAL} ArgoCD apps Synced."
    break
  fi
  info "Attempt ${i}/30 — ${SYNCED}/${TOTAL} apps synced. Retrying in 10s..."
  sleep 10
done

step_end "Step 4: App of Apps"

# ─── Step 5: Verify ────────────────────────────────────────────────────────────
header "Step 5 — Verify cluster"
step_start "Step 5: verify-cluster.sh"

scp -i ~/.ssh/k8s-platform-lab-key -o StrictHostKeyChecking=no \
  scripts/verify-cluster.sh \
  ec2-user@"${PUBLIC_IP}":~

VERIFY_OUTPUT=$(ssh -i ~/.ssh/k8s-platform-lab-key -o StrictHostKeyChecking=no \
  ec2-user@"${PUBLIC_IP}" \
  "export PATH=/usr/local/bin:\$PATH && bash verify-cluster.sh")

echo "$VERIFY_OUTPUT"

CHECKS_PASS=$(echo "$VERIFY_OUTPUT" | grep -c "PASS" || true)

step_end "Step 5: verify-cluster.sh"

# ─── Summary ───────────────────────────────────────────────────────────────────
DR_END=$(now_epoch)
DR_TOTAL=$(( DR_END - DR_START ))

header "Recovery Summary"

printf "%-35s %s\n" "Step" "Duration"
printf "%-35s %s\n" "─────────────────────────────────" "────────"
for step in "${STEP_ORDER[@]}"; do
  duration=$(( STEP_END["$step"] - STEP_START["$step"] ))
  printf "%-35s %s\n" "${step}" "$(elapsed_fmt $duration)"
done
echo ""
echo -e "${BOLD}Total recovery time : $(elapsed_fmt $DR_TOTAL)${NC}"
echo -e "${BOLD}Checks passing      : ${CHECKS_PASS}/21${NC}"
echo -e "${BOLD}New public IP       : ${PUBLIC_IP}${NC}"

# ─── Runbook table row ─────────────────────────────────────────────────────────
header "Paste this into docs/disaster-recovery.md → Tested table"

echo "| ${DR_DATE} | Achille Traore | $(elapsed_fmt $DR_TOTAL) | ${CHECKS_PASS}/21 checks passing. New IP: ${PUBLIC_IP} |"
