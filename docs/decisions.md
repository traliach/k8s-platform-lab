# Architecture Decision Records

Key technical decisions made during the build of `k8s-platform-lab`.
Each record follows the format: context → options considered → decision → consequences.

---

## ADR-001 — Single-node k3s over managed Kubernetes (EKS)

**Status:** Accepted

**Context:**
The project needs a Kubernetes cluster on AWS. The most obvious production choice
would be EKS (Elastic Kubernetes Service). The question was whether to use a managed
service or self-manage the cluster.

**Decision:**
Use k3s on a single EC2 instance, not EKS or any other managed service.

**Options considered:**

| Option | Verdict |
|--------|---------|
| EKS | Rejected — the managed control plane abstracts away exactly what this project exists to demonstrate: cluster operations, bootstrap, ingress configuration, storage, and observability wiring |
| kubeadm | Rejected — requires manual etcd, CNI plugin selection, and control-plane assembly. Adds complexity without adding learning value for a single-node setup |
| minikube / kind | Rejected — local-only tools, not suitable for a cloud VM or external network access |
| k3s | Accepted — single binary, production-grade, installs in under 60 seconds, ships Traefik and CoreDNS pre-configured, runs comfortably on a t3.medium |

**Consequences:**
- All cluster operations (bootstrap, upgrade, failure recovery) are visible and owned
- No managed control plane cost (~$0.10/hr for EKS endpoint)
- Single point of failure — no multi-node redundancy, by design for this lab
- Upgrade path is explicit (`k3s channel` or manual binary replacement)

---

## ADR-002 — GitOps with ArgoCD App-of-Apps pattern

**Status:** Accepted

**Context:**
Applications need to be deployed to the cluster. The options were: direct `kubectl apply`,
Helm from CI, or a GitOps controller that watches the repository continuously.

**Decision:**
Use ArgoCD with the App-of-Apps pattern. A root Application watches
`gitops/argocd/apps/`. Each file in that directory defines a child Application.
Nothing is applied to the cluster directly.

**Options considered:**

| Option | Verdict |
|--------|---------|
| kubectl apply from CI | Rejected — CI applies on push only. Drift between cluster state and Git is not detected or corrected |
| Helm from CI | Rejected — same problem as above. No continuous reconciliation |
| Flux | Not chosen — ArgoCD was selected for its UI, which makes the GitOps state visible and is useful for demonstrating the system |
| ArgoCD (single app) | Insufficient — managing each app manually in ArgoCD doesn't scale. App-of-Apps means adding an application = adding one YAML file |

**Consequences:**
- Git is the single source of truth. Manual changes to the cluster are reverted on the next sync
- Adding an application requires one file in `gitops/argocd/apps/` and a push to `main`
- ArgoCD polls every 3 minutes by default — changes are not instant (configurable with webhooks)
- Self-healing is enabled: if a resource is deleted in the cluster, ArgoCD recreates it

---

## ADR-003 — kube-prometheus-stack over separate Prometheus + Grafana installs

**Status:** Accepted

**Context:**
The observability stack needs Prometheus, Grafana, and the Prometheus Operator
(to support ServiceMonitor CRDs). These can be installed as separate Helm charts
or as a single umbrella chart.

**Decision:**
Use `kube-prometheus-stack` — the Prometheus Community umbrella chart that bundles
Prometheus, Alertmanager, Grafana, Prometheus Operator, kube-state-metrics, and
node-exporter in a single release.

**Options considered:**

| Option | Verdict |
|--------|---------|
| Separate charts (prometheus, grafana, prometheus-operator) | Rejected — requires coordinating compatible versions, separate RBAC rules, manual datasource wiring, and separate values files. More moving parts with no benefit for this project |
| kube-prometheus-stack | Accepted — ships pre-wired. One ArgoCD application, one values file, all components at known compatible versions |

**Consequences:**
- `ServerSideApply=true` is required in the ArgoCD application because the chart
  generates manifests that exceed the 256 KB annotation limit of client-side apply
- Grafana is included — a separate Grafana release must not be deployed into the same
  namespace (causes port conflicts). Grafana configuration happens via the stack's values file
- Chart upgrades update all components together — not independent versioning

---

## ADR-004 — Grafana dashboard delivery via Kustomize ConfigMap and sidecar

**Status:** Accepted

**Context:**
Grafana dashboards need to be in Git and applied to the cluster without manual
import through the Grafana UI. Two mechanisms are available: Grafana's built-in
dashboard provisioning via ConfigMap mount, or the Grafana sidecar container.

**Decision:**
Use the Grafana sidecar container approach shipped with kube-prometheus-stack.
Dashboard JSON lives in `observability/grafana/dashboards/`. A Kustomize
`configMapGenerator` creates a ConfigMap with the label `grafana_dashboard: "1"`.
The sidecar watches for ConfigMaps with that label and loads them automatically.

**How it works:**
```
Git: observability/grafana/dashboards/sample-app.json
  → ArgoCD applies Kustomize output
    → ConfigMap grafana-dashboard-sample-app (label: grafana_dashboard=1)
      → Grafana sidecar detects ConfigMap
        → Dashboard appears in Grafana UI
```

**Key configuration decision:** `disableNameSuffixHash: true` in `kustomization.yaml`.
By default Kustomize appends a content hash to ConfigMap names. The sidecar watches
by label, not by name — a changing name would create orphaned ConfigMaps on each sync.
Disabling the hash gives the ConfigMap a stable name that ArgoCD can update in place.

**Consequences:**
- Adding a dashboard = add a JSON file, reference it in `kustomization.yaml`, push to `main`
- No manual Grafana interaction required. Dashboards survive Grafana pod restarts
- Dashboard JSON must use the correct Prometheus datasource UID (`prometheus` — the
  default set by kube-prometheus-stack). If panels show "no data", verify the UID in
  Grafana → Configuration → Data Sources

---

## ADR-005 — ServiceMonitor over pod annotations for Prometheus scraping

**Status:** Accepted

**Context:**
Prometheus can discover scrape targets two ways: pod annotations
(`prometheus.io/scrape: "true"`) or ServiceMonitor CRDs managed by the Prometheus
Operator.

**Decision:**
Use a ServiceMonitor CRD in the `sample-app` namespace. Pod annotations are also
present as a belt-and-suspenders fallback.

**Why ServiceMonitor:**

| Aspect | Pod annotations | ServiceMonitor |
|--------|----------------|----------------|
| Scope | Cluster-wide, any annotated pod | Explicit selector — only targets matching pods |
| Configuration | Fixed — path, port, interval set in annotations | Configurable per ServiceMonitor |
| GitOps | Defined in the Deployment manifest | Separate resource — independently versioned |
| Prometheus Operator | Not required | Required — but already present in kube-prometheus-stack |

**Critical configuration:** The Prometheus Operator defaults to watching ServiceMonitors
only in its own namespace (`monitoring`). Cross-namespace discovery requires:

```yaml
# observability/prometheus/values.yaml
prometheusSpec:
  serviceMonitorSelectorNilUsesHelmValues: false
```

Without this flag, the ServiceMonitor in `sample-app` is invisible to Prometheus.

**Consequences:**
- Prometheus scrapes both sample-app pods every 30 seconds via the service port
- The scrape interval in the ServiceMonitor (`interval: 30s`) must match the
  global `scrapeInterval` in the Prometheus values — mismatching causes gaps in graphs
- Any new application that needs Prometheus scraping requires its own ServiceMonitor
  and the cross-namespace flag is already set

---

## ADR-006 — Multi-stage Docker build

**Status:** Accepted

**Context:**
The sample app has two parts: a React frontend (requires Node.js build tooling to
compile) and an Express backend (runs Node.js at runtime). Both need to be in the
same container image since the Express server serves the compiled React output.

**Decision:**
Two-stage Dockerfile: a `builder` stage installs all Vite/React dev dependencies
and compiles the frontend, then a `runner` stage copies only the compiled output
and the production server — no dev tooling in the final image.

```dockerfile
FROM node:20-alpine AS builder   # Vite, React, dev deps
RUN npm run build                # outputs client/dist

FROM node:20-alpine AS runner    # Express + prom-client only
COPY --from=builder /app/client/dist ./client/dist
USER appuser                     # non-root
```

**Consequences:**
- Final image contains no build tools, no dev dependencies, no source JSX
- Image size is significantly smaller than a single-stage build
- The runner stage runs as a non-root user (`appuser`) — a container escape through
  the application process has limited privilege on the host
- Node 20 LTS is pinned at the major version — patch updates are picked up
  automatically on rebuild; a specific digest would be required for full pinning

---

## What was not built (and why)

| Feature | Reason not included |
|---------|-------------------|
| TLS / HTTPS | Requires a domain name and cert-manager or ACM. Out of scope for a lab focused on platform operations, not certificate management |
| Elastic IP | Cost (~$3.65/month when unattached). Documented gap — the public IP changes on instance restart |
| Multi-node cluster | Adds CNI cross-node networking, node-to-node authentication, and load balancer complexity that does not serve the project's learning goals |
| Sealed Secrets / external secret store | The Grafana password in values.yaml is the only credential that would benefit. Out of scope for this iteration |
| EKS / managed Kubernetes | Explicitly rejected — see ADR-001 |
