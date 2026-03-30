# k8s-platform-lab

> Self-hosted Kubernetes platform — k3s, ArgoCD GitOps, Prometheus, Grafana, Node.js sample app, Terraform-provisioned cloud VM

![CI](https://github.com/traliach/k8s-platform-lab/actions/workflows/ci.yml/badge.svg)
![License](https://img.shields.io/github/license/traliach/k8s-platform-lab)
![Tag](https://img.shields.io/github/v/tag/traliach/k8s-platform-lab)

## Architecture

<!-- Add architecture diagram here -->
```
[diagram coming soon]
```

## Prerequisites

- [Terraform](https://terraform.io) >= 1.5
- [AWS CLI](https://aws.amazon.com/cli/) configured
- [kubectl](https://kubernetes.io/docs/tasks/tools/) (if K8s)

## Quick start

```bash
git clone https://github.com/traliach/k8s-platform-lab.git
cd k8s-platform-lab
cp terraform.tfvars.example terraform.tfvars
# fill in your values
terraform init
terraform plan
terraform apply
```

## Structure

```
k8s-platform-lab/
├── infra/          # Terraform modules
├── .github/        # CI/CD workflows
├── docs/           # Architecture diagrams and runbooks
├── CHANGELOG.md
└── README.md
```

## Deployment

See [CONTRIBUTING.md](./CONTRIBUTING.md) for branch and PR workflow.

## License

[MIT](./LICENSE) © 2026 Achille Traore | [achille.tech](https://achille.tech)
