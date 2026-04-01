#!/usr/bin/env bash
# setup-prerequisites.sh
# Generates a local SSH key pair and sets all required GitHub Actions secrets.
# Terraform will upload the public key to AWS — do not create the key pair manually.
# Run once before Sprint 1 (Terraform).
# Usage: bash scripts/setup-prerequisites.sh

set -euo pipefail

# ─── Config ────────────────────────────────────────────────────────────────────
AWS_REGION="us-east-1"
KEY_NAME="k8s-platform-lab-key"
KEY_PATH="$HOME/.ssh/${KEY_NAME}"
GITHUB_REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo '')"
# ───────────────────────────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

echo ""
echo "=========================================="
echo "  k8s-platform-lab — Prerequisites Setup  "
echo "=========================================="
echo ""

# ─── Preflight ─────────────────────────────────────────────────────────────────
command -v aws       >/dev/null 2>&1 || error "aws CLI not found. Install: https://aws.amazon.com/cli/"
command -v gh        >/dev/null 2>&1 || error "gh CLI not found. Install: https://cli.github.com/"
command -v ssh-keygen >/dev/null 2>&1 || error "ssh-keygen not found."

info "Verifying AWS credentials..."
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null) \
  || error "AWS credentials not configured. Run: aws configure"
success "AWS account: $AWS_ACCOUNT_ID"

info "Verifying GitHub auth..."
gh auth status >/dev/null 2>&1 || error "Not logged in to GitHub. Run: gh auth login"
success "GitHub: $(gh api user -q .login)"

if [[ -z "$GITHUB_REPO" ]]; then
  echo ""
  read -rp "Enter your GitHub repo (owner/repo): " GITHUB_REPO
fi

echo ""

# ─── Step 1: Generate SSH key pair locally ─────────────────────────────────────
info "Step 1/3 — Generating SSH key pair locally"

if [[ -f "$KEY_PATH" ]]; then
  warn "Key already exists at $KEY_PATH — skipping generation."
else
  mkdir -p "$(dirname "$KEY_PATH")"
  ssh-keygen -t ed25519 -C "$KEY_NAME" -f "$KEY_PATH" -N ""
  chmod 600 "$KEY_PATH"
  chmod 644 "${KEY_PATH}.pub"
  success "Private key : $KEY_PATH"
  success "Public key  : ${KEY_PATH}.pub"
fi

echo ""
info "Public key that Terraform will upload to AWS:"
cat "${KEY_PATH}.pub"
echo ""

# ─── Step 2: Docker Hub credentials ───────────────────────────────────────────
info "Step 2/3 — Docker Hub credentials"
echo ""
read -rp "  Docker Hub username: " DOCKER_USERNAME
read -rsp "  Docker Hub password/token: " DOCKER_PASSWORD
echo ""

# ─── Step 3: Set GitHub Actions secrets ───────────────────────────────────────
echo ""
info "Step 3/3 — Setting GitHub Actions secrets on '$GITHUB_REPO'"

AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id)
AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key)
PUBLIC_KEY_CONTENT=$(cat "${KEY_PATH}.pub")

set_secret() {
  local name="$1"
  local value="$2"
  printf "  Setting %-30s ... " "$name"
  echo "$value" | gh secret set "$name" --repo "$GITHUB_REPO"
  echo -e "${GREEN}done${NC}"
}

set_secret "DOCKER_USERNAME"        "$DOCKER_USERNAME"
set_secret "DOCKER_PASSWORD"        "$DOCKER_PASSWORD"
set_secret "AWS_ACCESS_KEY_ID"      "$AWS_ACCESS_KEY_ID"
set_secret "AWS_SECRET_ACCESS_KEY"  "$AWS_SECRET_ACCESS_KEY"
set_secret "TF_VAR_aws_region"      "$AWS_REGION"
set_secret "TF_VAR_public_key"      "$PUBLIC_KEY_CONTENT"

# ─── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "=========================================="
success "Sprint 0 prerequisites complete!"
echo ""
echo "  SSH private key : $KEY_PATH  (never commit this)"
echo "  SSH public key  : ${KEY_PATH}.pub"
echo ""
echo "  GitHub secrets set:"
echo "    - DOCKER_USERNAME"
echo "    - DOCKER_PASSWORD"
echo "    - AWS_ACCESS_KEY_ID"
echo "    - AWS_SECRET_ACCESS_KEY"
echo "    - TF_VAR_aws_region"
echo "    - TF_VAR_public_key"
echo ""
warn "Terraform will upload the public key to AWS automatically."
warn "Your private key never leaves your machine."
echo "=========================================="
echo ""
echo "Next step: Sprint 1 — write Terraform in infra/"
echo ""
