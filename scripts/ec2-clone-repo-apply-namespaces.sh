#!/usr/bin/env bash
# Run ON the EC2 instance (browser SSH or SSH) after k3s is installed.
# Fixes: no repo on disk, missing git on AL2023, kubectl apply path errors.
#
# Usage:
#   curl -fsSL -o /tmp/bootstrap.sh \
#     https://raw.githubusercontent.com/traliach/k8s-platform-lab/main/scripts/ec2-clone-repo-apply-namespaces.sh
#   bash /tmp/bootstrap.sh
#
# Or copy-paste this file and: bash ec2-clone-repo-apply-namespaces.sh

set -euo pipefail

export PATH="/usr/local/bin:$PATH"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "ERROR: kubectl not in PATH. Install k3s first, then:"
  echo "  export PATH=\"/usr/local/bin:\$PATH\""
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo "[INFO] git not found — installing (sudo dnf install -y git)..."
  sudo dnf install -y git
fi

REPO_URL="${REPO_URL:-https://github.com/traliach/k8s-platform-lab.git}"
BRANCH="${BRANCH:-main}"
TARGET="${HOME}/k8s-platform-lab"

if [[ -d "${TARGET}/.git" ]]; then
  echo "[INFO] Repo exists — updating ${BRANCH}..."
  git -C "${TARGET}" fetch origin
  git -C "${TARGET}" checkout "${BRANCH}"
  git -C "${TARGET}" pull --ff-only origin "${BRANCH}" || true
else
  echo "[INFO] Cloning ${REPO_URL} (${BRANCH})..."
  git clone --branch "${BRANCH}" --depth 1 "${REPO_URL}" "${TARGET}"
fi

kubectl apply -f "${TARGET}/cluster/namespaces.yaml"
echo ""
echo "[OK] Namespaces applied."
echo "Next:"
echo "  cd ${TARGET}"
echo "  bash cluster/bootstrap/install-argocd.sh"
echo "  kubectl apply -f gitops/argocd/app-of-apps.yaml"
