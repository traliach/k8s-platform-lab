# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [v1.0.0] — 2026-04-04

### Added
- `docs/architecture.md` — full system diagram, component rationale, request/metrics/GitOps data flows, infrastructure sizing, security posture
- `docs/decisions.md` — six Architecture Decision Records (ADR-001 through ADR-006) covering k3s, ArgoCD app-of-apps, kube-prometheus-stack, dashboard delivery, ServiceMonitor, and multi-stage Docker build
- `scripts/verify-cluster.sh` — end-to-end health check script: node, ServiceLB, Traefik, namespaces, ArgoCD apps, sample app endpoints, Prometheus targets, Grafana dashboard ConfigMap

### Fixed
- `lint.yml` kubectl dry-run job: added `--validate=false` to prevent OpenAPI schema download failure in CI (no cluster available in GitHub Actions)
- ServiceLB disabled on running cluster: `--disable servicelb` removed from k3s systemd service; Traefik LoadBalancer now has external IP and port 80 is accessible
- Orphaned standalone Grafana deployment and service deleted from `monitoring` namespace (left behind when ArgoCD application was removed without a resources finalizer)

## [v0.1.1] — 2026-04-02

### Added
- Argo CD NodePort diagnostic script (`scripts/diagnose-argocd-nodeport.sh`)
- EC2 clone + namespace bootstrap helper (`scripts/ec2-clone-repo-apply-namespaces.sh`)
- ServiceLB enabled in `cluster/bootstrap/install-k3s.sh` for Traefik external access

### Changed
- Standalone `grafana.yaml` Argo CD application removed — Grafana now ships inside `kube-prometheus-stack`
- `gitops/argocd/apps/grafana-dashboards.yaml` added as replacement for Kustomize-based dashboard delivery
- `observability/prometheus/values.yaml` upgraded from stub to real overrides (retention, scrape interval, resource limits, Grafana sidecar dashboard loader)

## [v0.1.0] — 2026-03-30

### Added
- Initial project scaffold
- Repository structure and configuration
- GitHub Actions CI/CD foundation (`lint.yml`, `release.yml`)
- Branch protection and label setup
- Terraform for AWS VPC, EC2 t3.medium, security group (ports 22, 80, 443, 6443, 30080)
- k3s bootstrap script with Traefik ingress
- ArgoCD bootstrap script (NodePort 30080)
- App-of-apps GitOps pattern (`gitops/argocd/app-of-apps.yaml`)
- Sample Node.js/Express + Vite app with `/health` and `/metrics` endpoints
- Kubernetes manifests: Deployment, Service, Ingress, HPA, ServiceAccount, ServiceMonitor
- kube-prometheus-stack ArgoCD application
- Grafana sample-app dashboard JSON + Kustomize ConfigMap
- `scripts/setup-prerequisites.sh` (SSH key generation, GitHub secrets)
