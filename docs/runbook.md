# k8s-platform-lab — Build Runbook

**Author:** Achille Traore | achille.tech
**Purpose:** This runbook documents every build step in order — what was done, why it was
done, and the exact commands used. It serves as both an operational reference and a
portfolio record of the decisions made during construction.

> Every decision in this document has a reason. Nothing was done by habit.

---

## Table of contents

1. [Repository and tooling setup](#1-repository-and-tooling-setup)
2. [Sprint 0 — Prerequisites](#2-sprint-0--prerequisites)
3. [Sprint 1 — Infrastructure (Terraform + AWS EC2)](#3-sprint-1--infrastructure-terraform--aws-ec2)
4. [Sprint 2 — Cluster Bootstrap (k3s + ArgoCD)](#4-sprint-2--cluster-bootstrap-k3s--argocd)

---

## 1. Repository and tooling setup

### What was done
The repository was initialized with a clear folder structure, a hardened `.gitignore`,
and working rules documented in `CLAUDE_project_b.md` / `.cursorrules`.

### Why
Starting with structure before code prevents the most common portfolio project failure:
a flat repository of loosely related files with no clear ownership. Each directory in
this project has a single responsibility:

| Directory | Owns |
|-----------|------|
| `infra/` | Cloud infrastructure only |
| `cluster/bootstrap/` | One-time cluster setup scripts |
| `apps/` | Application source code and k8s manifests |
| `gitops/` | ArgoCD delivery manifests |
| `observability/` | Prometheus and Grafana config |
| `scripts/` | Local developer tooling |
| `docs/` | Architecture diagrams and runbooks |

### Why credentials are stored as GitHub Actions secrets — not in files

The setup script (`scripts/setup-prerequisites.sh`) uses the `gh` CLI to push
credentials directly into GitHub's encrypted secret store. They never touch the
filesystem or appear in any file in the repository.

This matters for three reasons:
1. **No accidental commits** — a credential that was never written to disk cannot
   accidentally be committed.
2. **Least privilege** — GitHub Actions jobs only receive the secrets they declare.
   No job can access secrets from another workflow.
3. **Auditability** — GitHub logs every secret access. A file-based approach
   provides no such audit trail.

```bash
# How secrets were set — run once from Git Bash
bash scripts/setup-prerequisites.sh
```

The script set these six secrets:

| Secret | Purpose |
|--------|---------|
| `DOCKER_USERNAME` | Docker Hub image push |
| `DOCKER_PASSWORD` | Docker Hub image push |
| `AWS_ACCESS_KEY_ID` | Terraform AWS provider auth |
| `AWS_SECRET_ACCESS_KEY` | Terraform AWS provider auth |
| `TF_VAR_aws_region` | Passed to Terraform as variable |
| `TF_VAR_public_key` | EC2 SSH key pair — public key only |

### Why an ed25519 key was generated locally — not in AWS

AWS can generate a key pair for you (`.pem` download). We did not use that method.

Instead, `ssh-keygen -t ed25519` was run locally, generating:
- `~/.ssh/k8s-platform-lab-key` — private key, stays only on your machine
- `~/.ssh/k8s-platform-lab-key.pub` — public key, uploaded to AWS by Terraform

**Why this is better:**
- The private key is never transmitted over any network
- AWS (and therefore any AWS breach) never has a copy of your private key
- ed25519 is smaller and more secure than RSA-2048
- The public key is not a secret — it can safely be stored in GitHub Secrets
  and passed to Terraform as `TF_VAR_public_key`

---

## 2. Sprint 0 — Prerequisites

### Goal
Everything that must exist before a single line of infrastructure is written.

### Checklist completed

- [x] SSH key pair generated at `~/.ssh/k8s-platform-lab-key`
- [x] GitHub Actions secrets set (6 secrets)
- [x] AWS credentials configured via `aws configure`
- [x] Full directory structure created with `.gitkeep` placeholders
- [x] `.gitignore` hardened with `*.pem`, `*.key`, `kubeconfig`, `*-secret.yaml`

### Key `.gitignore` additions and why

```gitignore
kubeconfig          # Contains cluster admin credentials — never commit
*.kubeconfig        # Same
*-secret.yaml       # Kubernetes secret manifests often contain base64 credentials
*.pem               # AWS private key format
*.key               # Generic private key format
*.tfvars            # May contain sensitive Terraform variable values
*.tfplan            # Terraform plan output can contain resource details
```

`.terraform.lock.hcl` is **intentionally committed**. It pins the exact provider
version used, ensuring that anyone who clones this repo and runs `terraform init`
gets the same provider binary. Without it, two developers could silently use
different provider versions.

---

## 3. Sprint 1 — Infrastructure (Terraform + AWS EC2)

### Goal
Provision an AWS EC2 instance (`t3.medium`) with a VPC, public subnet, internet
gateway, and security group — all via Terraform. No manual console clicks for
infrastructure.

### Why Terraform and not the AWS Console

Every resource created via the console is invisible to the next person who clones
this repo. Terraform makes the infrastructure:
- **Reproducible** — anyone can run `terraform apply` and get the same result
- **Reviewable** — infrastructure changes go through Git and PR review
- **Destroyable** — `terraform destroy` cleans up everything cleanly

### Why a remote S3 backend for Terraform state

Terraform state (`terraform.tfstate`) records the real-world IDs of every resource
it manages. Storing it locally means:
- It cannot be shared with a team
- It can be accidentally committed (contains sensitive values)
- It can be lost if the local machine is lost

The state is stored in S3 bucket `achille-tf-state` with DynamoDB table
`k8s-platform-lab-tf-lock` for state locking. The lock table prevents two
simultaneous `terraform apply` runs from corrupting the state.

The DynamoDB table was created manually in the AWS Console (not via Terraform)
because it must exist *before* Terraform can use it — a chicken-and-egg problem.
Creating it manually is intentional and documented here.

### Why t3.medium and not a free-tier instance

The minimum viable stack for this project is:
- k3s (Kubernetes control plane + worker)
- ArgoCD (GitOps controller)
- Prometheus + Grafana (observability)

`t2.micro` (1 vCPU, 1GB RAM) — free tier — **will OOM**. Prometheus alone needs
~400MB. ArgoCD needs ~300MB. k3s needs ~200MB. The math does not work.

`t3.medium` (2 vCPU, 4GB RAM) is the minimum that runs the full stack reliably.
Cost: ~$0.04/hr. Stop the instance when not in use to minimize spend.

### Why `prevent_destroy = true` on the EC2 instance

```hcl
lifecycle {
  prevent_destroy = true
}
```

This prevents `terraform destroy` from deleting the VM accidentally. The cluster
bootstrap, ArgoCD state, and all deployed workloads live on this instance. An
accidental destroy would require rebuilding the entire cluster from scratch.
To intentionally destroy, this flag must be removed first — a deliberate gate.

### Why the security group allows only 5 ports

```
22    — SSH (cluster access and script execution)
80    — HTTP (Traefik ingress for the sample app)
443   — HTTPS (reserved for TLS termination)
6443  — Kubernetes API (kubectl remote access)
30080 — ArgoCD NodePort UI
```

Everything else is denied by default. No port ranges, no 0.0.0.0/0 on internal
ports. The principle of least privilege applied at the network layer.

### Terraform file responsibilities

| File | Responsibility |
|------|---------------|
| `variables.tf` | All input variables with descriptions and types. No hardcoded values. |
| `main.tf` | Provider config, required versions, S3 backend. |
| `networking.tf` | VPC, subnet, IGW, route table, security group. |
| `vm.tf` | EC2 instance, key pair upload, root volume. |
| `outputs.tf` | Public IP, instance ID, ready-to-use SSH command. |

### Commands run

```bash
# Format all .tf files before committing (rule: always run before commit)
cd infra && terraform fmt

# Initialise providers and configure S3 backend
terraform init

# Validate configuration syntax
terraform validate
# Output: Success! The configuration is valid.

# Preview changes — always review before applying
terraform plan

# Apply — creates 8 resources
terraform apply
# Output: Apply complete! Resources: 8 added, 0 changed, 0 destroyed.
# instance_id = "i-04966673c857d9ae3"
# public_ip   = "18.206.152.239"
# ssh_command = "ssh -i ~/.ssh/k8s-platform-lab-key ec2-user@18.206.152.239"
```

### Verify SSH access

```bash
ssh -i ~/.ssh/k8s-platform-lab-key ec2-user@18.206.152.239
# Expected: Amazon Linux 2023 welcome banner, shell prompt
```

---

## 4. Sprint 2 — Cluster Bootstrap (k3s + ArgoCD)

### Goal
Install k3s on the EC2 instance and deploy ArgoCD into the cluster, ready to
receive GitOps application manifests.

### Why k3s and not kubeadm, minikube, or EKS

| Option | Why not used |
|--------|-------------|
| kubeadm | Production-grade but requires manual etcd, CNI, and control-plane setup. Too much overhead for a single-node demo. |
| minikube | Local development only. Not suitable for a cloud VM. |
| kind | Kubernetes-in-Docker. Same problem as minikube. |
| EKS / GKE / DOKS | Managed services hide the cluster operations. The point of this project is to *do* the cluster operations. |
| **k3s** | Lightweight, production-grade, single binary. Ships with Traefik ingress, CoreDNS, and containerd. Installs in under 60 seconds. |

### Why scripts were run non-interactively over SSH

The bootstrap scripts were run like this:

```bash
ssh -i ~/.ssh/k8s-platform-lab-key ec2-user@18.206.152.239 "bash install-k3s.sh"
```

Not like this:

```bash
ssh -i ~/.ssh/k8s-platform-lab-key ec2-user@18.206.152.239
# then manually typing commands
```

**Why non-interactive matters:**
1. **Reproducibility** — the exact script is version-controlled. Interactive
   sessions are not recorded and cannot be replayed.
2. **No typos** — commands executed from a file are identical every time.
3. **Exit code propagation** — `set -euo pipefail` in the scripts means any
   failure stops execution immediately. An interactive session requires manual
   error checking after every command.
4. **Automation readiness** — the same pattern works from a CI/CD pipeline.
   The scripts are already pipeline-compatible.

### Why the scripts are idempotent

Both `install-k3s.sh` and `install-argocd.sh` check if the software is already
running before installing:

```bash
# install-k3s.sh
if systemctl is-active --quiet k3s 2>/dev/null; then
  success "k3s is already running — skipping install."
  exit 0
fi
```

**Why this matters:** If the VM is rebooted, or the script is run again to verify
the state, it will not attempt to reinstall and break a working cluster. Idempotent
scripts are safe to run multiple times — a critical property for operational tooling.

### Why Traefik was kept (not replaced)

k3s ships with Traefik as its default ingress controller. We kept it because:
- It requires zero additional configuration for basic ingress
- It is already included in the k3s binary — no extra Helm chart or manifest needed
- Replacing it with nginx-ingress would add complexity without adding value for
  this project's goals

### Why ArgoCD is exposed on NodePort 30080 and not via ingress

At this stage of the build, the ingress controller (Traefik) has no TLS certificate
configured. Exposing ArgoCD via ingress without TLS would mean the admin password
travels over plain HTTP. NodePort 30080 is a temporary exposure method during
construction. In a production setup, ArgoCD would sit behind a TLS-terminated
ingress or be accessed via `kubectl port-forward`.

### Why the ArgoCD admin password must be changed immediately

ArgoCD generates a random initial password stored in a Kubernetes secret
(`argocd-initial-admin-secret`). After changing your password:

```bash
argocd account update-password
```

Delete the initial secret — it is no longer needed and should not persist:

```bash
kubectl delete secret argocd-initial-admin-secret -n argocd
```

### Commands run

```bash
# Copy bootstrap scripts to the VM
scp -i ~/.ssh/k8s-platform-lab-key \
  cluster/bootstrap/install-k3s.sh \
  cluster/bootstrap/install-argocd.sh \
  ec2-user@18.206.152.239:~

# Install k3s v1.31.4+k3s1 (non-interactive, idempotent)
ssh -i ~/.ssh/k8s-platform-lab-key ec2-user@18.206.152.239 "bash install-k3s.sh"
# Output: Node k8s-platform-lab-node — Ready, control-plane/master

# Install ArgoCD v2.13.3 (non-interactive, idempotent)
ssh -i ~/.ssh/k8s-platform-lab-key ec2-user@18.206.152.239 "bash install-argocd.sh"
# Output: ArgoCD install complete, NodePort 30080, initial password printed
```

### Cluster state after Sprint 2

```
Node:     k8s-platform-lab-node   Ready   control-plane/master   v1.31.4+k3s1
IP:       10.0.1.15 (private) / 18.206.152.239 (public)
OS:       Amazon Linux 2023
Kernel:   6.1.61-85.141.amzn2023.x86_64
Runtime:  containerd://1.7.23-k3s2

ArgoCD:   http://18.206.152.239:30080
          Username: admin
          Password: [retrieved from install script — change immediately]
```

---

---

## 5. Issues, decisions, and Q&A log

This section is a running log of every question asked, problem hit, and decision
made during the build. Updated after every session.

---

### Session 1 — 2026-03-30 / 2026-04-02

---

**Q: Why not use DigitalOcean?**
A: AWS was chosen because the account was already created and AWS has broader
ecosystem coverage for demonstrating platform engineering skills (IAM, VPC, SGs,
S3 backend, service quotas). DigitalOcean would also have worked — the Terraform
would be similar.

---

**Q: Can we use AWS free tier (t2.micro)?**
A: No. t2.micro has 1 vCPU and 1GB RAM. The stack needs:
- k3s: ~200MB
- ArgoCD: ~300MB
- Prometheus: ~400MB
- Grafana: ~150MB
- Sample app: ~50MB
Total: >1GB — t2.micro would OOM. Minimum viable is t3.medium (2 vCPU, 4GB RAM).

---

**Q: Why not 3 EC2 instances and connect them?**
A: Out of scope per project rules. Multi-node adds CNI config, node-to-node
networking, and load balancer complexity that isn't the goal here. Single VM
demonstrates all the platform skills needed.

---

**Q: Why use a `.tfvars` file? I use it for modular environments.**
A: You're right that `.tfvars` is for environment separation (dev/staging/prod).
In this single-environment project it was only used to supply the sensitive
`public_key` variable locally. The cleaner approach is a shell env variable:
`export TF_VAR_public_key="$(cat ~/.ssh/k8s-platform-lab-key.pub)"`
The `.tfvars` file is gitignored and was a temporary convenience.

---

**Q: Can I create the DynamoDB lock table with Terraform?**
A: Chicken-and-egg problem — the table must exist before Terraform can use it
for state locking. Adding it to the same Terraform config that uses it as a
backend requires a two-step apply (`-target` first, then migrate backend).
Decision: create it manually in the AWS Console once. It's a one-time bootstrap
resource, not application infrastructure. Documented here so it's not lost.

---

**Issue: `terraform apply` failed — t3.medium not eligible for free tier**
Error:
```
api error InvalidParameterCombination: The specified instance type is not
eligible for Free Tier.
```
Diagnosis: Brand new AWS account with 24-hour activation hold on non-free-tier
instances. The error message is misleading — it's not a quota issue (quota was 5
vCPUs, sufficient). It's an account age restriction.
Resolution: Ran `terraform apply` again ~30 minutes later. It succeeded without
any changes to the configuration. The hold lifted automatically.

---

**Issue: ArgoCD CLI not found on the VM**
Error: `-bash: argocd: command not found`
Cause: The ArgoCD *server* was installed (via the Kubernetes manifest) but the
ArgoCD *CLI binary* was not. These are separate things.
Resolution: Downloaded the CLI binary matching the server version and installed it:
```bash
curl -sSL -o /tmp/argocd https://github.com/argoproj/argo-cd/releases/download/v2.13.3/argocd-linux-amd64
sudo install -m 555 /tmp/argocd /usr/local/bin/argocd
```

---

**Q: Why not log into the machine directly and run commands manually?**
A: Scripts run non-interactively over SSH (`ssh user@host "bash script.sh"`) are:
1. Reproducible — the exact commands are version-controlled in the repo
2. Error-safe — `set -euo pipefail` stops on any failure automatically
3. Audit-ready — the script is the record; interactive sessions are not
4. CI-compatible — the same pattern works from GitHub Actions without changes
Interactive sessions are fine for debugging but should never be the primary
method for provisioning or configuration.

---

**Q: Should the runbook be committed to the repo?**
A: No. It is a personal operational and decision log. Added to `.gitignore`:
`docs/runbook.md`
It stays local only and is updated frequently throughout the build.
