# Disaster Recovery Runbook — k8s-platform-lab

## What this covers

Full cluster loss — the EC2 instance is gone, all cluster state is lost.
All application state is stateless and recoverable from Git via ArgoCD.

## Recovery time objective (RTO)

Target: under 30 minutes from scratch.

## Prerequisites

- AWS CLI configured with profile `terraform-deployer`
- Terraform >= 1.5 installed
- kubectl installed locally
- `TF_VAR_public_key` set (your ed25519 SSH public key content)
- This repo cloned locally

---

## Recovery steps

### Step 1 — Reprovision the VM (~5 min)

```bash
cd infra
terraform init
terraform plan -var-file=terraform.tfvars   # confirm resources look correct
terraform apply -var-file=terraform.tfvars
```

Note the new public IP from the output:

```bash
terraform output public_ip
# or use the ready-made SSH command:
terraform output ssh_command
```

Wait ~60 seconds for the instance to pass EC2 health checks before SSHing in.

---

### Step 2 — Bootstrap k3s (~3 min)

Copy the bootstrap scripts to the new instance and run them:

```bash
PUBLIC_IP=$(terraform output -raw public_ip)

scp -i ~/.ssh/k8s-platform-lab-key \
  ../cluster/bootstrap/install-k3s.sh \
  ../cluster/bootstrap/install-argocd.sh \
  ec2-user@${PUBLIC_IP}:~

ssh -i ~/.ssh/k8s-platform-lab-key ec2-user@${PUBLIC_IP} \
  "bash install-k3s.sh"
```

Expected output: `[OK] k3s install complete!` and node status `Ready`.

---

### Step 3 — Install ArgoCD (~3 min)

```bash
ssh -i ~/.ssh/k8s-platform-lab-key ec2-user@${PUBLIC_IP} \
  "bash install-argocd.sh"
```

Expected output: `[OK] ArgoCD install complete!` with the initial admin password printed.
ArgoCD UI will be available at: `http://<PUBLIC_IP>:30080`

---

### Step 4 — Apply App of Apps (~2 min)

Pull the kubeconfig from the new instance and apply the root ArgoCD Application:

```bash
# Get kubeconfig from the new node
scp -i ~/.ssh/k8s-platform-lab-key \
  ec2-user@${PUBLIC_IP}:~/.kube/config \
  ~/.kube/k8s-platform-lab-config

export KUBECONFIG=~/.kube/k8s-platform-lab-config

# Verify connection
kubectl get nodes

# Apply the App of Apps — ArgoCD will sync everything from Git automatically
kubectl apply -f ../gitops/argocd/app-of-apps.yaml
```

ArgoCD will now sync all apps from the `main` branch:
- `sample-app` (Deployment, Service, Ingress, HPA, PDB)
- `prometheus` (kube-prometheus-stack)
- `grafana` (dashboards + custom values)

Wait 3–5 minutes for all pods to reach Running state:

```bash
kubectl get pods -A --watch
```

---

### Step 5 — Verify (~3 min)

```bash
# Copy and run the verification script
scp -i ~/.ssh/k8s-platform-lab-key \
  ../scripts/verify-cluster.sh \
  ec2-user@${PUBLIC_IP}:~

ssh -i ~/.ssh/k8s-platform-lab-key ec2-user@${PUBLIC_IP} \
  "bash verify-cluster.sh"
```

Expected: **21/21 checks passing**.

Spot-check key resources:

```bash
kubectl get pdb -n sample-app          # sample-app-pdb should show ALLOWED DISRUPTIONS: 1
kubectl get hpa -n sample-app          # HPA should show current/target replicas
kubectl get apps -n argocd             # all apps should show Synced + Healthy
```

---

## Post-recovery checklist

- [ ] ArgoCD UI accessible at `http://<NEW_IP>:30080`
- [ ] All 4 ArgoCD apps show `Synced` + `Healthy`
- [ ] Sample app responding at `http://<NEW_IP>/`
- [ ] `/health` endpoint returns `{"status":"ok"}`
- [ ] `/metrics` endpoint returns Prometheus metrics
- [ ] Grafana dashboard showing live data at `http://<NEW_IP>:30080` (via ArgoCD ingress) or NodePort
- [ ] 21/21 verify-cluster.sh checks passing
- [ ] Update this runbook's **Tested** section below with actual date and time

---

## What is NOT recovered

| Item | Reason | Action |
|------|--------|--------|
| ArgoCD admin password | Regenerated on fresh install | Set new password after login |
| Grafana admin password | Reset to Helm chart default | Update via Helm values |
| Historical Prometheus metrics | Not persisted (no PVC) | Metrics restart from zero |

All application configuration and Kubernetes manifests are fully recovered from Git.

---

## Tested

| Date | Performed by | Time to recover | Notes |
|------|-------------|-----------------|-------|
| TBD  | Achille Traore | TBD | First DR test — run `bash scripts/dr-timer.sh` and paste output here |

> **Instructions:** Run `bash scripts/dr-timer.sh` from the repo root. It times each step
> automatically and prints the exact table row to paste here when done.
