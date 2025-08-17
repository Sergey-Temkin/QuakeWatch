# QuakeWatch

## Phase 1: Foundation - Docker

**Objective:**
The purpose of Phase 1 is to establish a solid foundation by applying Docker concepts to create
a basic environment for containerized applications.
QuakeWatch: https://github.com/EduardUsatchev/QuakeWatch.git

**Tasks:**
1. **QuakeWatch Python Flask Application:**

    - *Create a simple Python Flask application that returns a "Hello, World!" message
    when accessed.*
    - *Create the necessary Docker resources to containerize the application. This
    includes writing a Dockerfile, creating a docker-compose.yml file, and updating
    the README with instructions on how to build and run the containerized version..*
    - *Build and tag the Docker image.*
    - *Push the Docker image to Docker Hub.*


2. **Containerization with Docker:**
    - *Install Docker and run your first container using the image you created.*
    - *Use Docker volumes to manage persistent storage if necessary.*

## Deliverables:
- *A zip file containing the Flask application and Dockerfile.*
- *A Docker image published on Docker Hub.*
- *Documentation on how to build and run the Docker container locally.*

## Project Structure:

```
QuakeWatch/
├── app.py                      # Application factory and entry point
├── dashboard.py                # Blueprint & route definitions using OOP style
├── Dockerfile                  # Instructions to build the Flask app Docker image
├── docker-compose.yml          # Compose setup for running the app with Docker
├── utils.py                    # Helper functions and custom Jinja2 filters
├── requirements.txt            # Python dependencies
├── static/
│   └── experts-logo.svg        # Logo file used in the UI
└── templates/                  # Jinja2 HTML templates
    ├── base.html               # Base template with common layout and navigation
    ├── main_page.html          # Home page content
    └── graph_dashboard.html    # Dashboard view with graphs and earthquake details
```

## Containerizing QuakeWatch:

1. **Refresh package list & provide SSL root certificates**
    ```bash 
    sudo apt update
    ``` 
    ```bash 
    sudo apt install -y curl ca-certificates conntrack
    ```
2. **Install and start Minikube**
    ```bash 
    minikube start --driver=docker --memory=2200mb --cpus=2
    ```
    ```bash 
    kubectl config use-context minikube
    ```
3. **Build the Docker image:** 
    ```bash
    docker build -t quakewatch:v1 .
    ```
4. **Authenticate with Docker Hub so you can push your image to your account**
    ```bash
    docker login
   ```
5. **Rebuild the image after making code changes, tagging it for Docker Hub**
    ```bash
    docker tag quakewatch:v1 <username>/quakewatch:v1
    ```
6. **Upload your Docker image to your Docker Hub repository**
    ```bash
    docker push <username>/quakewatch:v1
    ```
7. **Pull and run your app image from Docker Hub with this command**
    ```bash
    docker run -p 5000:5000 <username>/quakewatch:v1
    ```
    ```bash
    docker run -p 5000:5000 -v $(pwd)/logs:/app/logs <username>/quakewatch:v1
    ```