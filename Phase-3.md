# QuakeWatch

## Phase 3: Automation - Package Management, Version Control & CI/CD
**Objective:**
Phase 3 focuses on automating the deployment process and improving version control practices.  
You will create Helm charts, set up Git repositories, and implement CI/CD pipelines using GitHub Actions.

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
```
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
```

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


## Version Control with Git
- Initialized a Git repository for QuakeWatch.  
- Configured user identity with `git config --global user.name` and `git config --global user.email`.  
- Created feature branches (`feature-readme-update`, `feature-values-update`) to demonstrate common Git workflows.  
- Committed changes to different branches and pushed to GitHub.  
- Opened Pull Requests (PRs) to merge feature branches into `main`.  
- Simulated and resolved a **merge conflict** in `README.md` by editing the same section differently in two branches.  
- Demonstrated cleanup of merged branches both locally and remotely.

## Main Commands Used:

### Create and switch to new branch:
```bash
git checkout -b feature-readme-update
```

### Stage and commit changes:
```bash
git add README.md
git commit -m "docs: update README with Future Work section"
```

### Push branch:
```bash
git push -u origin feature-readme-update
```

### Merge into main
```bash
git checkout main
git merge feature-readme-update
```

### Resolve conflicts, then:
```bash
git add README.md
git commit
git push
```

## CI/CD Pipeline with GitHub Actions
- Created a workflow at `.github/workflows/ci.yml`.
- Configured a matrix build to test against `Python 3.10, 3.11, 3.12`.
- Added pylint linting with a lenient `.pylintrc`.
- Implemented a smoke test that imports the Flask app and tests `/`.
- Added a Docker build job to verify the Dockerfile compiles.
- Added a deploy job that triggers only on Git tags (`vX.Y.Z`).
- Bumps `Chart.yaml` version to match the tag.
- Packages Helm chart.
- Pushes chart to GHCR (`ghcr.io/sergey-temkin/charts/quakewatch`).

## Note on authentication:
To allow Helm to push charts to GHCR, a Personal Access Token (PAT) with write:packages and read:packages scope was created and added to GitHub Actions secrets (e.g., GHCR_PAT).  
This resolved the 403 denied error when pushing charts.


## Key Commands & Triggers:

### Push code (triggers test & docker-build jobs)
```bash
git push
```

### Tag release (triggers deploy job)
```bash
git tag v0.1.2
git push origin v0.1.2
```

### Verify chart exists in GHCR
```bash
helm show chart oci://ghcr.io/sergey-temkin/charts/quakewatch --version 0.1.2
```

### Install chart from GHCR
```bash
helm install quakewatch oci://ghcr.io/sergey-temkin/charts/quakewatch \
  --version 0.1.2 -n quake --create-namespace
```