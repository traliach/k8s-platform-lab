# Contributing to k8s-platform-lab

## Branch workflow

1. Branch from `main`: `git checkout -b <type>/short-description`
2. Make the smallest possible change — one concern per commit
3. Open a Pull Request against `main`
4. All CI checks must pass before merging
5. Never commit directly to `main`

## Branch naming

| Type | Pattern |
|------|---------|
| Feature | `feat/short-description` |
| Bug fix | `fix/short-description` |
| Infrastructure | `infra/short-description` |
| Kubernetes | `k8s/short-description` |
| GitOps / ArgoCD | `gitops/short-description` |
| Observability | `obs/short-description` |
| CI/CD | `ci/short-description` |
| Docs | `docs/short-description` |

## Commit messages (Conventional Commits)

```
feat: add k3s bootstrap script
infra: provision AWS EC2 with Terraform
gitops: add ArgoCD app-of-apps manifest
k8s: add sample-app Deployment with resource limits
obs: configure kube-prometheus-stack Helm values
ci: add helm lint step to lint workflow
docs: add architecture diagram to README
fix: correct Prometheus scrape interval for sample app
chore: update prerequisites setup script
```

Rules:
- One logical change per commit
- No vague messages (`fix stuff`, `update`, `wip`)
- Always run `terraform fmt` before committing `.tf` files
- Always run `helm lint` before committing Helm values

## Pull Request checklist

- [ ] `helm lint` passes on any changed Helm values
- [ ] `kubectl --dry-run=client` passes on any changed k8s manifests
- [ ] `terraform fmt` run on any changed `.tf` files
- [ ] No secrets, kubeconfig, `.pem`, `.tfstate`, or `.tfvars` committed
- [ ] No `latest` image tag used anywhere
- [ ] `CHANGELOG.md` updated if this is a user-facing change
- [ ] PR description explains what and why

## What belongs where

| Change | Directory |
|--------|-----------|
| Cloud VM, networking, firewall | `infra/` |
| k3s or ArgoCD install scripts | `cluster/bootstrap/` |
| Namespace definitions | `cluster/namespaces.yaml` |
| Application source code | `apps/sample-app/src/` |
| Kubernetes manifests for the app | `apps/sample-app/k8s/` |
| ArgoCD Application manifests | `gitops/argocd/apps/` |
| Prometheus/Grafana config | `observability/` |
| GitHub Actions workflows | `.github/workflows/` |
| Setup scripts | `scripts/` |
| Diagrams and guides | `docs/` |

Do not create files outside this structure.

## Questions?

Open an issue or reach out at [achille.tech](https://achille.tech)
