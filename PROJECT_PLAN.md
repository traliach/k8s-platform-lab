# k8s-platform-lab — Project Plan
**Author:** Achille Traore | achille.tech
**Cloud:** AWS EC2
**Methodology:** Agile — sequential sprints, one deliverable confirmed before the next begins
**Last updated:** 2026-03-30

---

## Infrastructure note

AWS free tier (`t2.micro`) is **not sufficient** for this stack.
Minimum required: **2 vCPU / 4 GB RAM**.
Recommended instance: `t3.medium` (~$0.04/hr, ~$30/month).
> Proceeding with `t3.medium` unless instructed otherwise.

---

## Dependency map (why this order)

```
Sprint 1 (Infra/Terraform)
    └── Sprint 2 (VM exists → install k3s + ArgoCD)
            └── Sprint 3 (Cluster exists → define namespaces + GitOps)
                    └── Sprint 4 (GitOps works → deploy sample app via ArgoCD)
                            └── Sprint 5 (App running → add observability)
                                    └── Sprint 6 (Everything works → automate with CI/CD)
                                            └── Sprint 7 (All green → document + final validation)
```

---

## Sprint 0 — Prerequisites & Repo Hygiene
**Goal:** Everything needed before writing a single line of infra.

| # | Task | File(s) | Done? |
|---|------|---------|-------|
| 0.1 | Confirm AWS region and key pair name | — | [ ] |
| 0.2 | Add secrets to GitHub repo (`TF_VAR_*`, `DOCKER_USERNAME`, `DOCKER_PASSWORD`) | GitHub Settings | [ ] |
| 0.3 | Verify `.gitignore` covers `*.pem`, `*.key`, `*.tfstate`, `*.tfvars`, `kubeconfig` | `.gitignore` | [ ] |
| 0.4 | Create repo folder structure (empty dirs + `.gitkeep`) | all top-level dirs | [ ] |

---

## Sprint 1 — Infrastructure (Terraform + AWS EC2)
**Goal:** Run `terraform apply` and have a live EC2 instance with correct firewall rules.
**Acceptance criteria:** `ssh ec2-user@<public-ip>` works; ports 22/80/443/6443 open; nothing else.

| # | Task | File(s) | Done? |
|---|------|---------|-------|
| 1.1 | Write `infra/variables.tf` (region, instance type, AMI, key name, CIDR) | `infra/variables.tf` | [ ] |
| 1.2 | Write `infra/main.tf` (provider + S3 backend block) | `infra/main.tf` | [ ] |
| 1.3 | Write `infra/networking.tf` (VPC, subnet, IGW, route table, security group) | `infra/networking.tf` | [ ] |
| 1.4 | Write `infra/vm.tf` (EC2 t3.medium, `prevent_destroy = true`, user_data for base packages) | `infra/vm.tf` | [ ] |
| 1.5 | Write `infra/outputs.tf` (public IP, instance ID) | `infra/outputs.tf` | [ ] |
| 1.6 | Run `terraform fmt` + `terraform validate` + `terraform plan` | — | [ ] |
| 1.7 | Apply and confirm SSH access | — | [ ] |

**Commit:** `infra: provision AWS EC2 with Terraform`

---

## Sprint 2 — Cluster Bootstrap (k3s + ArgoCD)
**Goal:** k3s running on the VM; ArgoCD installed and accessible.
**Acceptance criteria:** `kubectl get nodes` shows Ready; ArgoCD UI reachable on port 30080.

| # | Task | File(s) | Done? |
|---|------|---------|-------|
| 2.1 | Write `cluster/bootstrap/install-k3s.sh` (idempotent, Traefik enabled) | `cluster/bootstrap/install-k3s.sh` | [ ] |
| 2.2 | Write `cluster/bootstrap/install-argocd.sh` (install + initial config + NodePort) | `cluster/bootstrap/install-argocd.sh` | [ ] |
| 2.3 | Write `cluster/namespaces.yaml` (`argocd`, `monitoring`, `sample-app`) | `cluster/namespaces.yaml` | [ ] |
| 2.4 | SSH to VM, run both scripts, verify cluster and ArgoCD | — | [ ] |

**Commits:**
- `k8s: add idempotent k3s bootstrap script`
- `k8s: add ArgoCD install and config script`
- `k8s: define all cluster namespaces`

---

## Sprint 3 — GitOps Foundation (ArgoCD App-of-Apps)
**Goal:** ArgoCD watches this repo and manages all apps from Git.
**Acceptance criteria:** ArgoCD UI shows the root app healthy and pointing to `gitops/argocd/apps/`.

| # | Task | File(s) | Done? |
|---|------|---------|-------|
| 3.1 | Write `gitops/argocd/install.yaml` (namespace + ArgoCD install manifest reference) | `gitops/argocd/install.yaml` | [ ] |
| 3.2 | Write `gitops/argocd/app-of-apps.yaml` (root Application, watches `main`, `gitops/argocd/apps/`) | `gitops/argocd/app-of-apps.yaml` | [ ] |
| 3.3 | Write stub `gitops/argocd/apps/sample-app.yaml` | `gitops/argocd/apps/sample-app.yaml` | [ ] |
| 3.4 | Write stub `gitops/argocd/apps/prometheus.yaml` | `gitops/argocd/apps/prometheus.yaml` | [ ] |
| 3.5 | Write stub `gitops/argocd/apps/grafana.yaml` | `gitops/argocd/apps/grafana.yaml` | [ ] |
| 3.6 | Bootstrap root app into ArgoCD (`argocd app create`) | — | [ ] |

**Commits:**
- `gitops: add ArgoCD app-of-apps root manifest`
- `gitops: add application manifests for sample-app, prometheus, grafana`

---

## Sprint 4 — Sample Application
**Goal:** Node.js app deployed via ArgoCD, accessible via public IP.
**Acceptance criteria:** `curl http://<public-ip>/health` returns `{"status":"ok"}`; `/metrics` returns Prometheus data.

| # | Task | File(s) | Done? |
|---|------|---------|-------|
| 4.1 | Write `apps/sample-app/src/index.js` (`/`, `/health`, `/metrics` with `prom-client`) | `apps/sample-app/src/index.js` | [ ] |
| 4.2 | Write `apps/sample-app/package.json` | `apps/sample-app/package.json` | [ ] |
| 4.3 | Write `apps/sample-app/Dockerfile` (node:20-alpine, non-root, `.dockerignore`) | `apps/sample-app/Dockerfile` | [ ] |
| 4.4 | Write `apps/sample-app/k8s/deployment.yaml` (2 replicas, probes, resource limits) | `apps/sample-app/k8s/deployment.yaml` | [ ] |
| 4.5 | Write `apps/sample-app/k8s/service.yaml` | `apps/sample-app/k8s/service.yaml` | [ ] |
| 4.6 | Write `apps/sample-app/k8s/ingress.yaml` (Traefik) | `apps/sample-app/k8s/ingress.yaml` | [ ] |
| 4.7 | Write `apps/sample-app/k8s/hpa.yaml` | `apps/sample-app/k8s/hpa.yaml` | [ ] |
| 4.8 | Build + push Docker image manually (first release), update ArgoCD app manifest | — | [ ] |
| 4.9 | Confirm ArgoCD syncs and app is healthy | — | [ ] |

**Commits:**
- `feat: add Node.js sample app with health and metrics endpoints`
- `k8s: add sample-app Deployment, Service, Ingress, HPA`
- `gitops: wire sample-app ArgoCD manifest to k8s manifests`

---

## Sprint 5 — Observability (Prometheus + Grafana)
**Goal:** Prometheus scraping the sample app; Grafana dashboard showing live metrics.
**Acceptance criteria:** Grafana shows request rate, error rate, response time for the sample app.

| # | Task | File(s) | Done? |
|---|------|---------|-------|
| 5.1 | Write `observability/prometheus/values.yaml` (kube-prometheus-stack overrides, scrape config for sample app) | `observability/prometheus/values.yaml` | [ ] |
| 5.2 | Update `gitops/argocd/apps/prometheus.yaml` (Helm Application, monitoring namespace) | `gitops/argocd/apps/prometheus.yaml` | [ ] |
| 5.3 | Update `gitops/argocd/apps/grafana.yaml` (Helm Application, custom credentials) | `gitops/argocd/apps/grafana.yaml` | [ ] |
| 5.4 | Write `observability/grafana/dashboards/sample-app.json` (request rate, error rate, p99 latency) | `observability/grafana/dashboards/sample-app.json` | [ ] |
| 5.5 | Confirm Prometheus scrapes `/metrics`; Grafana dashboard loads | — | [ ] |

**Commits:**
- `obs: configure kube-prometheus-stack Helm values`
- `obs: add sample-app Grafana dashboard`

---

## Sprint 6 — CI/CD (GitHub Actions)
**Goal:** Every PR lints; every merge to main tags, builds, and pushes the Docker image.
**Acceptance criteria:** Both workflows green on `main`; new image tag appears in GHCR/Docker Hub on merge.

| # | Task | File(s) | Done? |
|---|------|---------|-------|
| 6.1 | Write `.github/workflows/lint.yml` (helm lint, kubectl dry-run, terraform validate, docker build smoke test) | `.github/workflows/lint.yml` | [ ] |
| 6.2 | Write `.github/workflows/release.yml` (git tag, docker build+push, GitHub release with CHANGELOG) | `.github/workflows/release.yml` | [ ] |
| 6.3 | Add all required GitHub Actions secrets | GitHub Settings | [ ] |
| 6.4 | Open a test PR, confirm `lint.yml` passes | — | [ ] |
| 6.5 | Merge to `main`, confirm `release.yml` tags and pushes | — | [ ] |

**Commits:**
- `ci: add helm lint and k8s dry-run workflow`
- `ci: add release tagging and Docker image push workflow`

---

## Sprint 7 — Documentation & Final Validation
**Goal:** README is complete; all deliverables checked off; project is reproducible by anyone.
**Acceptance criteria:** All 17 checklist items in `CLAUDE_project_b.md` section 15 are green.

| # | Task | File(s) | Done? |
|---|------|---------|-------|
| 7.1 | Create `docs/architecture.png` (architecture diagram) | `docs/architecture.png` | [ ] |
| 7.2 | Write `docs/setup.md` (step-by-step from zero to running) | `docs/setup.md` | [ ] |
| 7.3 | Update `README.md` (overview, prerequisites, quickstart, architecture diagram) | `README.md` | [ ] |
| 7.4 | Update `CHANGELOG.md` with v1.0.0 entry | `CHANGELOG.md` | [ ] |
| 7.5 | Final end-to-end validation: push commit → ArgoCD syncs → metrics appear in Grafana | — | [ ] |

**Commits:**
- `docs: add architecture diagram and setup guide`
- `docs: update README with full setup instructions`
- `chore: update CHANGELOG for v1.0.0`

---

## Summary — deliverable-to-sprint map

| Deliverable | Sprint |
|-------------|--------|
| `infra/` Terraform | 1 |
| `cluster/bootstrap/install-k3s.sh` | 2 |
| `cluster/bootstrap/install-argocd.sh` | 2 |
| `cluster/namespaces.yaml` | 2 |
| `gitops/argocd/app-of-apps.yaml` | 3 |
| `gitops/argocd/apps/` (3 manifests) | 3 |
| `apps/sample-app/` (src + Dockerfile) | 4 |
| `apps/sample-app/k8s/` (4 manifests) | 4 |
| `observability/prometheus/values.yaml` | 5 |
| `observability/grafana/dashboards/sample-app.json` | 5 |
| `.github/workflows/lint.yml` | 6 |
| `.github/workflows/release.yml` | 6 |
| `docs/architecture.png` | 7 |
| `README.md` (complete) | 7 |
| All GitHub Actions green | 6–7 |
| ArgoCD UI healthy | 3–5 |
| Grafana dashboard live | 5 |
| Sample app accessible | 4 |

---

## Rules in effect
- One sprint at a time. No sprint starts until the previous one is confirmed working.
- One commit per logical change.
- No files outside the defined architecture structure.
- No secrets committed. Ever.
- All changes go through a PR — never commit directly to `main`.
