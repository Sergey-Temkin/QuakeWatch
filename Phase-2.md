# QuakeWatch

## Phase 2: Orchestration - Kubernetes Basics & Advanced
**Objective:**
In Phase 2, you will build upon your containerization knowledge by orchestrating your
application using Kubernetes. The goal is to deploy a scalable and highly available application.

**Tasks:**

1. **Kubernetes Cluster Setup:**
    - *Set up a Kubernetes cluster using Minikube or k3s.*
    - *Deploy your Dockerized web application as a Kubernetes Pod.*

2. **Basic Kubernetes Resources:**
   - *Create a Deployment and ReplicaSet for managing the application.*
   - *Expose the application externally using a Kubernetes Service.*
   - *Implement Horizontal Pod Autoscaling (HPA) based on CPU usage.*

3. **Advanced Kubernetes Concepts:**
   - *Use ConfigMaps and Secrets to manage configuration.*
   - *Set up Kubernetes CronJobs to automate periodic tasks.*
   - *Implement Liveness and Readiness Probes for monitoring application health.*

## Deliverables:
- *Zip file contains Updated Part 1 and:*
- *Kubernetes manifests for Deployment, Service, HPA, ConfigMaps, Secrets, and CronJobs.*
- *Documentation on setting up the Kubernetes cluster and deploying the application.*

## Project Structure:

```
├── app.py                  # Application factory and entry point
├── dashboard.py            # Blueprint & route definitions using OOP style
├── utils.py                # Helper functions and custom Jinja2 filters
├── requirements.txt        # Python dependencies
├── Dockerfile              # Instructions to build the Flask app Docker image
├── docker-compose.yml      # Compose setup for running the app with Docker
├── k8s/                    # Kubernetes manifests for orchestration (Phase 2)
│ ├── deployment.yaml       # Deployment & ReplicaSet for the Flask app
│ ├── service.yaml          # Service to expose the application
│ ├── hpa.yaml              # Horizontal Pod Autoscaler (HPA) based on CPU usage
│ ├── configmap.yaml        # ConfigMap for environment variables & configs
│ ├── secret.yaml           # Secret for sensitive values
│ ├── cronjob.yaml          # CronJob for periodic background tasks
│ ├── liveness-probe.yaml   # Liveness probe configuration
│ └── readiness-probe.yaml  # Readiness probe configuration
├── static/
│ └── experts-logo.svg      # Logo file used in the UI
└── templates/              # Jinja2 HTML templates
├── base.html               # Base template with common layout and navigation
├── main_page.html          # Home page content
└── graph_dashboard.html    # Dashboard view with graphs and earthquake details

```

## Orchestration - Kubernetes Basics

1. **Start Minikube cluster:**

    ```bash
    minikube start --driver=docker --memory=2200mb --cpus=2
    kubectl config use-context minikube
    ```
2. **Enable metrics for HPA:**
    ```bash
    minikube addons enable metrics-server
    ```    
3. **Apply Kubernetes manifests:**
    ```bash
    kubectl apply -f k8s/configmap.yaml
    kubectl apply -f k8s/secret.yaml
    kubectl apply -f k8s/deployment.yaml
    kubectl apply -f k8s/svc.yaml
    kubectl apply -f k8s/hpa.yaml
    kubectl apply -f k8s/cronjob.yaml

    kubectl get deploy,rs,pods,svc,hpa,cronjob -l app=quakewatch                                                    # quick view
    ```  
4. **Make sure Deployment uses the pushed tag:**
    ```bash
    kubectl set image deploy/quakewatch app=docker.io/$USER/$APP:$VER                                               # set exact image
    kubectl rollout status deploy/quakewatch                                                                        # wait until rollout completes
    kubectl get pods -l app=quakewatch -w                                                                           # watch pods to 1/1 Ready
    ```  
5. **Open the app:**
    ```bash
    kubectl port-forward svc/quakewatch-svc 8080:80
    # Leave this running, then open:
    http://localhost:8080
    ```   
6. **Validations:**

    ### Endpoints & Pods:
    ```bash
    kubectl get endpoints quakewatch-svc                                                                            # should list 2 endpoints (two pods)
    curl -s http://$(minikube ip):$(kubectl get svc quakewatch-svc -o jsonpath='{.spec.ports[0].nodePort}')/health  # expect 200
    ```

    ### ConfigMap & Secret envs inside a pod:
    ```bash
    POD=$(kubectl get pods -l app=quakewatch -o jsonpath='{.items[0].metadata.name}')
    kubectl exec -it "$POD" -- sh -c 'echo $LOG_LEVEL && echo $API_TOKEN'                                           # should print values
    ```

    ### HPA presence & metrics:
    ```bash
    kubectl get hpa quakewatch-hpa
    kubectl top pods                                                                                                # requires metrics-server
    ```

    ### CronJob presence & last job logs:
    ```bash
    kubectl get cronjob quakewatch-ping
    kubectl get jobs --sort-by=.metadata.creationTimestamp | tail
    JOB=$(kubectl get jobs --no-headers | awk '/quakewatch-ping/{print $1}' | tail -n1)
    PODJ=$(kubectl get pods --no-headers | awk -v j="$JOB" '$1 ~ j {print $1}' | head -n1)
    kubectl logs "$PODJ"  
    ```