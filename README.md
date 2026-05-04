# Cloud Native Demo

A production-like cloud-native reference project for a small Flask microservice deployed to Kubernetes with Terraform, Helm, GitHub Actions, ArgoCD, Prometheus, Grafana, and Loki.

## Architecture

```text
GitHub Actions -> container registry -> Helm values update
                                      |
                                      v
Terraform -> Minikube + platform add-ons -> ArgoCD -> Helm chart -> Kubernetes workload
                                                |
                                                v
                                      Prometheus/Grafana/Loki
```

- **Application:** Flask service exposing `/health`, `/api`, and `/metrics`.
- **Container:** non-root Python image with a Docker health check and Gunicorn runtime.
- **Kubernetes:** Deployment, Service, Ingress, probes, resource requests/limits, HPA.
- **Helm:** environment-specific values for dev and prod.
- **Terraform:** modular local Minikube provisioning and platform add-ons, with an EKS extension point.
- **GitOps:** ArgoCD Application watches the Helm chart and auto-syncs.
- **Observability:** kube-prometheus-stack, Grafana dashboard, Loki, Promtail, and structured app logs.

## Repository layout

```text
app/                         Flask app, Dockerfile, Python dependencies
argocd/                      ArgoCD Application manifest
helm/cloud-native-demo/       Helm chart and dev/prod values
infra/terraform/              Root Terraform and modules
infra/terraform/modules/      Minikube, platform add-ons, and EKS extension point
k8s/                         Raw Kubernetes manifests equivalent to the chart
observability/                Grafana/Loki/Prometheus values and dashboard
scenarios/failure/            Failure simulation manifests and values
.github/workflows/            CI/CD workflow
```

## Prerequisites

Install these locally when running the full stack:

- Docker
- kubectl
- minikube
- Terraform >= 1.6
- Helm >= 3

## Local setup

### 1. Provision the cluster and platform add-ons

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform apply
```

The Minikube module enables the `ingress` and `metrics-server` add-ons. The platform module installs:

- ArgoCD in `argocd`
- kube-prometheus-stack/Grafana in `monitoring`
- Loki and Promtail in `monitoring`

Apply the dashboard after the monitoring stack is ready:

```bash
kubectl apply -f ../../observability/dashboard-configmap.yaml
```

### 2. Build and load the local image

```bash
docker build -t cloud-native-demo:dev ../../app
minikube -p cloud-native-demo image load cloud-native-demo:dev
```

### 3. Deploy with Helm

```bash
helm upgrade --install cloud-native-demo ../../helm/cloud-native-demo \
  -n cloud-native-demo --create-namespace \
  -f ../../helm/cloud-native-demo/values-dev.yaml
```

### 4. Test the service

```bash
kubectl -n cloud-native-demo port-forward svc/cloud-native-demo-cloud-native-demo 8080:80
curl http://127.0.0.1:8080/health
curl http://127.0.0.1:8080/api
curl http://127.0.0.1:8080/metrics
```

For ingress-based access, map the Minikube IP to the local hostname:

```bash
echo "$(minikube -p cloud-native-demo ip) cloud-native-demo.local" | sudo tee -a /etc/hosts
curl http://cloud-native-demo.local/api
```

## GitOps with ArgoCD

Edit `argocd/application.yaml` before applying it:

- Replace `https://github.com/OWNER/REPO.git` with this repository URL.
- Set `targetRevision` to the branch ArgoCD should track.
- Keep `path: helm/cloud-native-demo` unless the chart moves.

Apply the application:

```bash
kubectl apply -f argocd/application.yaml
```

Access ArgoCD locally:

```bash
kubectl -n argocd port-forward svc/argocd-server 8081:80
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
```

Then open `http://127.0.0.1:8081` and log in as `admin`.

## CI/CD

`.github/workflows/build-and-update-chart.yaml` runs on pushes to `main` that affect the app, chart, or workflow. It:

1. Builds the Docker image from `app/`.
2. Pushes image tags to GitHub Container Registry (`ghcr.io`).
3. Updates `helm/cloud-native-demo/values-prod.yaml` with the new immutable SHA tag.
4. Commits the chart value update back to the branch.

For another Docker registry, change `REGISTRY`, `IMAGE_NAME`, and the registry login step.

## Observability

### Metrics

The service exposes Prometheus metrics at `/metrics`:

- `app_http_requests_total` by method, endpoint, and status
- `app_http_request_duration_seconds` histogram by method and endpoint

The Helm chart annotates pods for scraping and can create a `ServiceMonitor` when `serviceMonitor.enabled=true`.

### Logs

The Flask app writes structured logs to stdout. Promtail ships container logs to Loki.

### Grafana

Port-forward Grafana:

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
```

Open `http://127.0.0.1:3000` and log in with `admin/admin` for local development. The dashboard includes:

- CPU usage by pod
- `/api` p95 request latency
- 5xx error rate
- Application logs from Loki

## Failure simulations

### Bad deployment

Deploy an invalid image tag:

```bash
helm upgrade --install cloud-native-demo helm/cloud-native-demo \
  -n cloud-native-demo \
  -f helm/cloud-native-demo/values-dev.yaml \
  -f scenarios/failure/bad-image-values.yaml
```

Detection signals:

- ArgoCD shows degraded/out-of-sync resources.
- `kubectl -n cloud-native-demo get pods` shows `ImagePullBackOff`.
- Grafana CPU/request panels stop receiving fresh application data.

Rollback:

```bash
helm rollback -n cloud-native-demo cloud-native-demo
```

### Latency and error spike

Inject app-level failures:

```bash
make failure-errors
for i in $(seq 1 100); do curl -s http://127.0.0.1:8080/api >/dev/null; done
```

Detection signals:

- Grafana p95 latency panel rises.
- Error-rate panel shows 5xx responses.
- Loki logs continue to show completed requests.

Rollback by redeploying dev values only:

```bash
helm upgrade --install cloud-native-demo helm/cloud-native-demo \
  -n cloud-native-demo -f helm/cloud-native-demo/values-dev.yaml
```

### High request load

Run the loader job:

```bash
make failure-cpu
kubectl -n cloud-native-demo get hpa -w
```

Detection signals:

- CPU usage panel rises.
- HPA increases desired replicas when metrics-server reports utilization above target.

## Production-like best practices included

- Non-root container user and dropped Linux capabilities.
- Liveness and readiness probes.
- Resource requests/limits and HPA.
- Immutable image tags in production CI/CD.
- GitOps-managed deployment with prune and self-heal.
- Separate dev/prod Helm values.
- Structured logs shipped to Loki.
- Terraform modules that separate cluster and platform concerns.

## EKS extension path

`infra/terraform/modules/eks-cluster` documents the intended production replacement for Minikube. A production implementation should use managed node groups, private networking, IRSA, KMS envelope encryption, cluster logging, and remote state outputs that feed the same Helm/Kubernetes provider configuration used by the platform add-ons.

## Troubleshooting

- **Terraform cannot reach Kubernetes:** verify `kubectl config current-context` matches `cloud-native-demo` and Minikube is running.
- **Ingress does not resolve:** confirm `minikube addons enable ingress` ran and `/etc/hosts` maps `cloud-native-demo.local` to `minikube ip`.
- **HPA shows unknown metrics:** confirm the Minikube `metrics-server` add-on is enabled and pods have CPU requests.
- **Grafana dashboard missing:** apply `observability/dashboard-configmap.yaml` and restart the Grafana pod if the sidecar has not picked it up.
- **ArgoCD cannot sync:** replace placeholder repo URL, ensure the target branch exists, and check ArgoCD repository credentials for private repositories.
