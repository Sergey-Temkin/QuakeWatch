# QuakeWatch

## Phase 3: Automation - Package Management, Version Control & CI/CD
**Objective:**
Phase 3 focuses on automating the deployment process and improving version control
practices. You will create Helm charts, set up Git repositories, and implement CI/CD pipelines
using GitHub Actions.

**Tasks:**

1. **Package Management with Helm:**
    - *Create a Helm chart for your Kubernetes application.*
    - *Publish the Helm chart to an artifact repository.*

2. **Version Control with Git:**
    - *Set up a Git repository for your project.*
    - *Create multiple branches and demonstrate common Git workflows.*
    - *Resolve conflicts and manage pull requests.*

3. **CI/CD Pipeline:**
    - *Use GitHub Actions to create a CI/CD pipeline.*
    - *Implement different stages in the pipeline (build, test, deploy).*
    - *Use matrix builds to test your application with pylint on multiple environments .*

## Deliverables:
- *A Helm chart published to an artifact repository.*
- *A Git repository with a clear branching strategy and documented workflows.*
- *A working CI/CD pipeline configured in GitHub Actions.*

## Project Structure:
QuakeWatch/
├── app.py # Flask app factory and logging setup
├── dashboard.py # Routes & earthquake data visualization
├── utils.py # Graph generation and data helpers
├── requirements.txt # Python dependencies
├── static/
│ └── experts-logo.svg # Logo for UI
├── templates/
│ ├── base.html # Common layout
│ ├── main_page.html # Home page
│ └── graph_dashboard.html# Graph dashboard
└── k8s/
└── helm/
└── quakewatch/
├── Chart.yaml # Helm chart metadata
├── values.yaml # Default configuration
└── templates/ # Deployment, Service, HPA, ConfigMap, Secret, CronJob


## Implementation Steps:

1. **Containerization (Phase 1)**  
   - Built a Docker image for QuakeWatch (`sergeytemkin/quakewatch:v1`).  
   - Verified the app runs locally with `docker run -p 5000:5000`.  

2. **Kubernetes (Phase 2)**  
   - Set up Minikube cluster.  
   - Enabled `metrics-server` for HPA.  
   - Created Deployment, Service, ConfigMap, Secret, CronJob YAMLs.  

3. **Helm (Phase 3)**  
   - Created a Helm chart under `k8s/helm/quakewatch`.  
   - Added reusable templates for Deployment, Service, HPA, ConfigMap, Secret, and CronJob.  
   - Verified locally with `helm upgrade --install`.  
   - Published Helm chart to **GHCR**:  
     `oci://ghcr.io/sergey-temkin/charts/quakewatch:0.1.0`.  
   - Installed from GHCR into Kubernetes and tested via port-forward.


## Main Commands Used

### Docker
```bash
docker build -t sergeytemkin/quakewatch:v1 .
docker push sergeytemkin/quakewatch:v1
docker run --rm -p 5000:5000 sergeytemkin/quakewatch:v1
minikube start --driver=docker
minikube addons enable metrics-server
kubectl top nodes
kubectl top pods
kubectl apply -f <manifest>.yaml
```

### Create Helm chart structure:
```bash
mkdir -p k8s/helm/quakewatch/templates
```

### Lint & dry-run:
```bash
helm lint k8s/helm/quakewatch
helm template quakewatch k8s/helm/quakewatch
```

### Install locally:
```bash
helm upgrade --install quakewatch k8s/helm/quakewatch -n quake
```

### Package chart:
```bash
helm package k8s/helm/quakewatch -d k8s/helm/dist
```

### Login & push to GHCR:
```bash
helm registry login ghcr.io -u Sergey-Temkin -p <TOKEN>
helm push k8s/helm/dist/quakewatch-0.1.0.tgz oci://ghcr.io/sergey-temkin/charts
```

### Install from GHCR:
```bash
helm install qw-ghcr oci://ghcr.io/sergey-temkin/charts/quakewatch --version 0.1.0 -n quake
```