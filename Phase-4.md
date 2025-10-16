# Phase 4: Advanced Automation – GitOps & Monitoring

## Objective:
Enhance your QuakeWatch deployment by implementing GitOps practices for
continuous deployment and setting up comprehensive monitoring using Prometheus
and Grafana.

### Tasks:

### GitOps with ArgoCD:
- ArgoCD Setup:
    - Install ArgoCD on your Kubernetes (k3s) cluster.
    - Configure ArgoCD to track a Git repository containing your Kubernetes manifests (or Helm charts) for QuakeWatch.
- Auto-Sync & Deployment Management:
    - Configure auto-sync policies so that changes in Git are automatically reflected in your cluster.
    - Implement sync waves and hooks for managing complex deployment scenarios if needed.
- Documentation:
    - Provide ArgoCD configuration files and a guide on how to use ArgoCD to manage your deployments.

### Monitoring with Prometheus & Grafana:
- Prometheus Installation:
    - Deploy Prometheus into your cluster to collect metrics from QuakeWatch and the cluster itself.
    - Configure Prometheus to scrape metrics from your application and Kubernetes components.
- Grafana Setup:
    - Install Grafana and connect it to Prometheus.
    - Create custom dashboards that visualize application metrics (e.g., CPU/memory usage, request rates, error rates) and cluster health.
- Alerting:
    - Configure alerting rules in Prometheus to notify you when critical issues arise (e.g., high error rates or pod failures).
- Documentation:
    - Document the Prometheus and Grafana setup along with sample dashboards and alerting configurations.

### Deliverables:
- ArgoCD configuration files and a documented guide for GitOps deployment.
- Prometheus and Grafana configuration manifests (or Helm charts) along with sample dashboards.
- Documentation on the GitOps and monitoring setup, including screenshots of dashboards and descriptions of alerting rules.
- Git repository with all the code

## Main Commands Used:

## GitOps with ArgoCD
### Install ArgoCD on your quakewatch-p4 cluster:
```bash
# 1) create namespace (idempotent)
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
# 2) install ArgoCD using the official stable manifest
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
# 3) watch pods until all are Ready (Ctrl+C when all show READY 1/1 or 2/2)
kubectl -n argocd get pods -w
```
### Login:
```bash
# port-forward the API server locally
kubectl -n argocd port-forward svc/argocd-server 8080:80
# Open another terminal and run:
# get the initial admin password (username is: admin)
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo
```
```bash
## use the Web UI
http://localhost:8080
```
###  Remove the one-off Helm release (single time):
```bash
helm uninstall quakewatch -n quakewatch
kubectl -n quakewatch get all
```
###  Create the ArgoCD Application (declarative YAML):
```bash
# apply quakewatch-app.yaml
kubectl apply -f argocd/quakewatch-app.yaml
# watch the ArgoCD Application object
kubectl -n argocd get applications.argoproj.io quakewatch -w
```
- In the ArgoCD UI (http://localhost:8080 via your port-forward):
    - You should see an app named quakewatch turn OutOfSync → Synced and Healthy after auto-sync.
    - If it’s OutOfSync and doesn’t auto-apply, click SYNC → SYNCHRONIZE once (or use CLI argocd app sync quakewatch).   
- Back in the terminal, confirm resources are back and owned by ArgoCD:  
```bash
kubectl -n quakewatch get deploy,svc,hpa,cronjob
kubectl -n quakewatch get pods -o wide
```
### Verify Auto-Sync (GitOps in action):
- Edit your `argocd/quakewatch-app.yaml`
```bash
# change this line:
schedule: "*/1 * * * *"
# to:
schedule: "*/2 * * * *"
# Save, then apply
kubectl apply -f argocd/quakewatch-app.yaml
kubectl -n argocd get applications quakewatch -w
# (it should flip OutOfSync → Synced)
# Then verify
kubectl -n quakewatch get cronjob quakewatch-quakewatch-ping -o jsonpath='{.spec.schedule}'; echo
# You should now see: schedule: "*/2 * * * *"
```
###  Sync Waves & Hooks (safe, controlled rollouts):
- After editing in `k8s/helm/quakewatch`:`templates/configmap.yaml`,`templates/postsync-smoketest-job.yaml`,`values.yaml`
- Commit and Push:
```bash
git add k8s/helm/quakewatch/templates/configmap.yaml \
        k8s/helm/quakewatch/templates/postsync-smoketest-job.yaml \
        k8s/helm/quakewatch/values.yaml
git commit -m "p4: add sync-wave for ConfigMap and PostSync smoketest hook"
git push
```
- Verify Everything:
```bash
# ConfigMap has wave -1
kubectl -n quakewatch get cm quakewatch-quakewatch -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/sync-wave}'; echo
# PostSync job exists & passed
kubectl -n quakewatch get jobs --sort-by=.metadata.creationTimestamp | grep postsync | tail -n 1
JOB=$(kubectl -n quakewatch get jobs -o name | grep postsync | tail -n1 | cut -d/ -f2)
# Health check
kubectl -n quakewatch logs job/$JOB | tail -n 10
```
## Monitoring (Prometheus & Grafana)
### Install the stack into monitoring namespace:
``` bash
# 1) Namespace
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# 2) Repos
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# 3) Minimal values (NodePort + enable cAdvisor metrics)
mkdir -p monitoring
cat <<'EOF' > monitoring/kube-prometheus-stack-values.yaml
grafana:
  adminPassword: "admin123"
  service:
    type: NodePort
    nodePort: 32000
  sidecar:
    dashboards:
      enabled: true
      label: grafana_dashboard
      folder: /var/lib/grafana/dashboards/custom

prometheus:
  service:
    type: NodePort
    nodePort: 32090

# IMPORTANT: enable kubelet cAdvisor so container CPU/memory are scraped
kubelet:
  serviceMonitor:
    cAdvisor: true
    probes: true
    resource: true
EOF

# 4) Install/upgrade
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring -f monitoring/kube-prometheus-stack-values.yaml

# 5) Wait until pods are Ready
kubectl -n monitoring get pods

# Expected when ready
monitoring-grafana-xxxxxx                   1/1   Running
monitoring-kube-prometheus-operator-xxxxx   1/1   Running
prometheus-monitoring-kube-prometheus-0     2/2   Running
alertmanager-monitoring-kube-prometheus-0   2/2   Running
# Once all pods show Running press Ctrl + C
# Verify
kubectl -n monitoring get pods
```
### Open Grafana & Prometheus:
- Run this in a new terminal (keep it open)
```bash
# Grafana (recommended)
minikube -p quakewatch-p4 service monitoring-grafana -n monitoring
# OR: kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80
```
- Login to Grafana with:
    - user: admin
    - pass: admin123 (we set this in values)
- Run this in a new terminal (keep it open)
```bash
# Prometheus
minikube -p quakewatch-p4 service monitoring-kube-prometheus-prometheus -n monitoring
# OR: kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090
```
### Auto-load a Grafana dashboard for QuakeWatch:
- Use a single YAML (no sed) so the sidecar imports it reliably.
```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: quakewatch-grafana-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
    app.kubernetes.io/instance: monitoring
data:
  quakewatch-dashboard.json: |
    {
      "title": "QuakeWatch — Pod Health",
      "schemaVersion": 39,
      "version": 7,
      "annotations": { "list": [ { "builtIn": 1, "type": "dashboard", "name": "Annotations & Alerts", "hide": true, "enable": true } ] },
      "panels": [
        {
          "type": "timeseries",
          "title": "Pod CPU (cores) — quakewatch",
          "targets": [
            { "expr": "sum by (pod) (rate(container_cpu_usage_seconds_total{pod=~\"quakewatch-.*\"}[5m]))" }
          ],
          "gridPos": { "h": 8, "w": 24, "x": 0, "y": 0 }
        },
        {
          "type": "timeseries",
          "title": "Pod Memory (working set bytes) — quakewatch",
          "targets": [
            { "expr": "sum by (pod) (container_memory_working_set_bytes{pod=~\"quakewatch-.*\"})" }
          ],
          "gridPos": { "h": 8, "w": 24, "x": 0, "y": 8 }
        },
        {
          "type": "stat",
          "title": "Pod Restarts (5m)",
          "targets": [
            { "expr": "sum by (pod) (increase(kube_pod_container_status_restarts_total{namespace=\"quakewatch\"}[5m]))" }
          ],
          "gridPos": { "h": 4, "w": 8, "x": 0, "y": 16 }
        }
      ]
    }
EOF
```
- Verify
    - Grafana → Dashboards → QuakeWatch — Pod Health → set Last 15 min → Refresh.
    - You should see CPU/Memory lines for quakewatch-* pods.
### Prometheus Alert Rules
- Create the alert file
```bash
mkdir -p monitoring/rules

cat <<'EOF' > monitoring/rules/quakewatch-alerts.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: quakewatch-alerts
  namespace: monitoring
  labels:
    release: kube-prometheus-stack        # ← REQUIRED for Prometheus to load it
spec:
  groups:
  - name: quakewatch.rules
    rules:
    # 🔹 High-CPU alert — fires easily for demo
    - alert: QuakeWatchHighCPU
      expr: |
        sum by (pod) (
          rate(container_cpu_usage_seconds_total{
            namespace="quakewatch",
            container!="POD"
          }[1m])
        ) > 0.01
      for: 15s
      labels:
        severity: warning
      annotations:
        summary: "High CPU in {{ $labels.pod }}"
        description: "CPU > 1% for 15 seconds in {{ $labels.pod }}"

    # 🔹 Pod-restart alert
    - alert: QuakeWatchPodRestarts
      expr: |
        sum by (pod) (
          increase(kube_pod_container_status_restarts_total{
            namespace="quakewatch"
          }[5m])
        ) > 0
      for: 0m
      labels:
        severity: warning
      annotations:
        summary: "Pod restarted: {{ $labels.pod }}"
        description: "One or more containers restarted in the last 5 minutes."
EOF

kubectl apply -f monitoring/rules/quakewatch-alerts.yaml
```
- Verify the rule is active
```bash
kubectl -n monitoring get prometheusrule quakewatch-alerts -o wide
```
- After port-forwarding or minikube service monitoring-kube-prometheus-prometheus -n monitoring, open:
```bash
http://127.0.0.1:9090/alerts
```
- You should see:
```bash  
| Alert name                | State                           | Description               |  
| ------------------------- | ------------------------------- | ------------------------- |  
| **QuakeWatchHighCPU**     | `FIRING` when CPU > 1% for 15 s | Validates app performance |  
| **QuakeWatchPodRestarts** | `FIRING` after any pod restart  | Detects unstable pods     |  
```

