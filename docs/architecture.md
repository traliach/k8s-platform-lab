# Architecture

## What this is

A self-hosted Kubernetes platform built on a single AWS EC2 instance, provisioned
with Terraform, operated with GitOps, and monitored with Prometheus and Grafana.

The goal was to build and operate every layer of the stack — infrastructure,
cluster, delivery, observability — rather than letting a managed service absorb the
complexity. Every component was chosen deliberately and can be explained.

---

## System diagram

```
┌─────────────────────────────────────────────────────────────────┐
│  Developer laptop                                               │
│                                                                 │
│  git push → github.com/traliach/k8s-platform-lab (main)        │
└──────────────────────┬──────────────────────────────────────────┘
                       │
              GitHub Actions
              ├── lint.yml       Helm lint, kubectl dry-run,
              │                  Terraform validate, Docker build
              └── release.yml    Git tag, Docker push, GitHub release
                       │
                       │  ArgoCD polls every 3 minutes
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│  AWS EC2  t3.medium  (us-east-1)                                │
│  Amazon Linux 2023 · 2 vCPU · 4 GB RAM                         │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  k3s v1.31 — single-node Kubernetes                     │   │
│  │                                                         │   │
│  │  namespace: argocd                                      │   │
│  │    ArgoCD v2.13 ──── app-of-apps ──────────────────┐   │   │
│  │                      ├── sample-app                 │   │   │
│  │                      ├── prometheus                 │   │   │
│  │                      └── grafana-dashboards         │   │   │
│  │                                                     │   │   │
│  │  namespace: sample-app          ◄───────────────────┘   │   │
│  │    Deployment (2 replicas)                               │   │
│  │    HPA  (min 2 · max 5 · 70% CPU)                       │   │
│  │    Service · Ingress · ServiceMonitor                    │   │
│  │                │                                         │   │
│  │                │  port 80 (Traefik ingress)              │   │
│  │                │  port 3000 (pod)                        │   │
│  │                │                                         │   │
│  │  namespace: monitoring          ◄───────────────────────┘   │
│  │    Prometheus  (scrapes /metrics every 30s)                  │
│  │    Grafana     (dashboard sidecar reads ConfigMap)           │
│  │    Alertmanager                                              │
│  │    kube-state-metrics · node-exporter                        │
│  │                                                         │   │
│  │  kube-system                                            │   │
│  │    Traefik  (ingress controller · port 80/443)          │   │
│  │    ServiceLB  (binds host ports to LoadBalancer svc)    │   │
│  │    CoreDNS · local-path-provisioner                     │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  Security group inbound: 22 · 80 · 443 · 6443 · 30080          │
└─────────────────────────────────────────────────────────────────┘
```

---

## Request path (sample app)

```
Browser → EC2 public IP :80
  → Traefik (ServiceLB bound to host port 80)
    → sample-app Service (ClusterIP :80)
      → sample-app Pod :3000
        ├── GET /          → React SPA (served from client/dist)
        ├── GET /health    → {"status":"ok"}
        └── GET /metrics   → Prometheus text format
```

## Metrics path

```
Prometheus ──scrapes every 30s──► sample-app Pod :3000/metrics
  └── stores http_requests_total, http_request_duration_seconds

Grafana sidecar ──watches──► ConfigMap grafana-dashboard-sample-app
  └── label: grafana_dashboard=1
    └── mounts JSON → Grafana renders 3 panels:
          request rate · error rate (5xx share) · p95 latency
```

## GitOps delivery path

```
git push to main
  → ArgoCD detects change (polls every 3 min)
    → app-of-apps syncs gitops/argocd/apps/
      ├── sample-app     applies apps/sample-app/k8s/
      ├── prometheus     renders kube-prometheus-stack Helm chart
      │                  with observability/prometheus/values.yaml
      └── grafana-dashboards  applies observability/grafana/dashboards/
                              via Kustomize (ConfigMapGenerator)
```

---

## Components

### Kubernetes — k3s

k3s is a single-binary, production-grade Kubernetes distribution from Rancher.
It ships with Traefik, CoreDNS, and containerd pre-configured. Installation takes
under 60 seconds with no manual CNI, etcd, or control-plane assembly.

The alternatives considered and why they were not chosen:

| Option | Why not used |
|--------|-------------|
| EKS | Managed control plane hides the operations this project exists to demonstrate |
| kubeadm | Requires manual etcd, CNI, and control-plane configuration — overhead without learning value for single-node |
| minikube / kind | Local-only. Not suitable for a cloud VM or external access |

### GitOps — ArgoCD (App-of-Apps pattern)

ArgoCD watches the Git repository and reconciles the cluster state to match. The
App-of-Apps pattern uses a single root Application that discovers child Applications
in `gitops/argocd/apps/`. Adding a new application means adding one YAML file and
pushing — ArgoCD handles the rest.

This enforces a hard rule: **nothing is applied to the cluster manually**. The Git
repository is the single source of truth.

### Infrastructure — Terraform

All AWS resources are defined in `infra/`: VPC, subnet, internet gateway, security
group, EC2 instance, and key pair. `terraform apply` creates a fully working
environment from scratch. `terraform destroy` removes it cleanly.

State is stored in S3 (`achille-tf-state`) with DynamoDB locking
(`k8s-platform-lab-tf-lock`) so it can be shared and is protected from concurrent
modification.

### Ingress — Traefik

k3s ships Traefik as its default ingress controller. It requires no additional
configuration for basic ingress routing and is included in the k3s binary. The
sample-app Ingress uses the `kubernetes.io/ingress.class: traefik` annotation.

External access on port 80 is provided by **ServiceLB** — k3s's built-in load
balancer implementation. ServiceLB deploys a DaemonSet pod that binds the host port
to the Traefik LoadBalancer service, assigning the node's private IP as the external
IP. The EC2 public IP routes through to this via the security group.

### Observability — kube-prometheus-stack

A single Helm umbrella chart that bundles Prometheus, Alertmanager, Grafana,
Prometheus Operator, kube-state-metrics, and node-exporter — all pre-wired.

Deploying these separately would require coordinating versions, RBAC rules, and
datasource configuration between them. kube-prometheus-stack ships this pre-integrated.

Prometheus discovers the sample app via a **ServiceMonitor** CRD. The key
configuration that makes cross-namespace discovery work:

```yaml
serviceMonitorSelectorNilUsesHelmValues: false
```

Without this flag, the Prometheus Operator only watches for ServiceMonitors in the
`monitoring` namespace. With it disabled, it watches cluster-wide and finds the
ServiceMonitor in the `sample-app` namespace.

Grafana dashboards are delivered via GitOps: a Kustomize ConfigMapGenerator creates
a ConfigMap with the label `grafana_dashboard: "1"`. Grafana's sidecar container
watches for ConfigMaps with that label and loads them automatically. No manual
dashboard import required.

### Sample application — Node.js + Express + React

The sample app serves three endpoints:

| Endpoint | Purpose |
|----------|---------|
| `GET /` | React SPA (GrowStrong meal plan — a real toddler nutrition app) |
| `GET /health` | `{"status":"ok"}` — used by readiness and liveness probes |
| `GET /metrics` | Prometheus text format — `prom-client` instrumentation |

Two metrics are exposed:
- `http_requests_total` — Counter, labelled by method, route, and status code
- `http_request_duration_seconds` — Histogram with buckets from 5ms to 5s

The container is built in two stages: a `builder` stage compiles the React client
with Vite, and a `runner` stage copies only the compiled output and the Express
server. The final image runs as a non-root user.

### CI/CD — GitHub Actions

Two workflows:

| Workflow | Trigger | What it does |
|----------|---------|-------------|
| `lint.yml` | Every push and PR | Terraform fmt + validate, Helm lint, Kustomize build, kubectl dry-run (client-side), Docker build smoke test |
| `release.yml` | Push to `main` | Reads version from `package.json`, creates a Git tag if it does not exist, builds and pushes the Docker image (if Docker secrets are configured), creates a GitHub release |

---

## Infrastructure sizing

| Resource | Spec | Reason |
|----------|------|--------|
| EC2 instance | t3.medium (2 vCPU, 4 GB) | Minimum that runs the full stack without OOM. t2.micro (1 GB) will not work — Prometheus alone needs ~400 MB |
| Root EBS volume | 20 GB (default) | Sufficient for container images, k3s state, and 15 days of Prometheus retention |
| Prometheus retention | 15 days | Enough for a lab; longer fills the root volume |
| Prometheus memory | 768 Mi request / 2 Gi limit | Observed minimum for this stack on t3.medium |

---

## Security posture (lab grade)

| Control | Implementation |
|---------|---------------|
| Network | Security group allows only ports 22, 80, 443, 6443, 30080 |
| Container | Non-root user, read-only where possible |
| Secrets | No secrets committed — credentials via GitHub Actions secrets |
| Grafana | Non-default credentials set in values.yaml (rotate in production) |
| Terraform state | S3 + DynamoDB — not local, not in Git |
| SSH | ed25519 key pair — private key never transmitted, never stored in AWS |

This is lab-grade security, not production. Gaps that would need to close for
production: TLS on all endpoints, Sealed Secrets or external secret store for
Grafana credentials, branch protection enforced on `main`, Elastic IP to avoid
IP rotation on instance restart.
