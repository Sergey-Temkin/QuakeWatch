# Phase 5: Cloud Deployment with k3s & Terraform

## Objective:
Deploy a highly available Kubernetes cluster on AWS using k3s and Terraform. This phase  
focuses on provisioning AWS infrastructure with Terraform and installing a lightweight  
Kubernetes distribution (k3s) to run your containerized QuakeWatch application.  

### Tasks:

1. AWS Infrastructure Provisioning:
- Terraform Configuration:
    - Write Terraform configurations to provision the required AWS resources (e.g., VPC, subnets, security groups, EC2 instances) for hosting your k3s cluster.
    - Ensure that the EC2 instances have appropriate IAM roles and network configurations for running Kubernetes.
- Documentation:
    - Document your VPC setup and network configuration in a vpc.tf file and accompanying README.  

2. Cluster Deployment with k3s:
- Installation:
    - Automate the installation of k3s on the provisioned EC2 instances (e.g.,using Terraform provisioners or a bootstrap script).
- QuakeWatch Deployment:
    - Deploy your QuakeWatch application to the newly created k3s cluster using Kubernetes manifests (or a Helm chart if available).
- Validation:
    - Verify that your cluster is running, and that QuakeWatch is accessible externally.

### Deliverables:
- Terraform configuration files (e.g., vpc.tf, instances.tf) for AWS infrastructure.
- Documentation detailing the AWS VPC, EC2 instances, and k3s installation process.
- Kubernetes manifests (or Helm charts) for deploying QuakeWatch on the k3s cluster

# AWS Infrastructure Provisioning(VPC, Subnets, SG, IAM):

## Terraform Configuration:

### AWS User + Key Pair Setup
```bash
# In AWS Console → IAM → Users → Create user
# Name: terraform-admin
# Permissions: attach `IAMFullAccess` (temporary)
# Download credentials (.csv)
aws configure
# Paste Access Key + Secret Key
```
### Create EC2 key pair
```bash
# In AWS Console → EC2 → Key Pairs → Create key pair
# Name: class11, Type: RSA, Format: PEM
# Download .pem file to Downloads and move to WSL:
cp "/mnt/c/Users/USER/Desktop/class11.pem" ~/.ssh/
chmod 400 ~/.ssh/class11.pem
ls -l ~/.ssh/class11.pem
```

### Working dir
```bash      
mkdir -p phase5/terraform && cd phase5/terraform
```
### providers.tf
```bash
cat > providers.tf <<'EOF'
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
EOF
```
### variables.tf
```bash
cat > variables.tf <<'EOF'
variable "project_name" {
  type        = string
  default     = "quakewatch"
  description = "Project tag/prefix"
}

variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.42.0.0/16"
  description = "VPC CIDR"
}

variable "az_count" {
  type        = number
  default     = 2
  description = "How many AZs/subnets to create"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  default     = ["10.42.1.0/24", "10.42.2.0/24", "10.42.3.0/24"]
  description = "At least az_count items"
}

variable "ssh_allowed_cidr" {
  type        = string
  default     = "0.0.0.0/0"
  description = "Your IP/CIDR for SSH (e.g., 203.0.113.4/32)"
}

# Optional IAM for SSM (we keep false because your user lacks IAM perms)
variable "enable_ssm" {
  type        = bool
  default     = false
  description = "Create EC2 IAM role/profile with SSM (needs IAM permissions)"
}

# (These are used later in Phase B, safe to define now)
variable "key_name" {
  type        = string
  description = "Existing AWS EC2 key pair name"
}

variable "instance_type" {
  type        = string
  default     = "t3.small"
  description = "EC2 size for k3s server"
}
EOF
```
### vpc.tf
```bash
cat > vpc.tf <<'EOF'
data "aws_availability_zones" "available" {}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "${var.project_name}-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${var.project_name}-public-rt" }
}

resource "aws_subnet" "public" {
  for_each = {
    for idx, az in local.azs :
    idx => { az = az, cidr = var.public_subnet_cidrs[idx] }
  }

  vpc_id                  = aws_vpc.main.id
  availability_zone       = each.value.az
  cidr_block              = each.value.cidr
  map_public_ip_on_launch = true

  tags = { Name = "${var.project_name}-public-${each.key}" }
}

resource "aws_route_table_association" "public_assoc" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}
EOF
```
### security_groups.tf
```bash
cat > security_groups.tf <<'EOF'
resource "aws_security_group" "k3s_nodes" {
  name        = "${var.project_name}-k3s-sg"
  description = "Base SG for k3s nodes"
  vpc_id      = aws_vpc.main.id

  # SSH
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  # Intra-cluster (all protocols inside VPC)
  ingress {
    description = "Intra-VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  # HTTP/HTTPS (for apps later)
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-k3s-sg" }
}
EOF
```

### iam.tf
```bash
cat > iam.tf <<'EOF'
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_role" {
  count              = var.enable_ssm ? 1 : 0
  name               = "${var.project_name}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  count      = var.enable_ssm ? 1 : 0
  role       = aws_iam_role.ec2_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  count = var.enable_ssm ? 1 : 0
  name  = "${var.project_name}-ec2-profile"
  role  = aws_iam_role.ec2_role[0].name
}
EOF
```
### outputs.tf
```bash
cat > outputs.tf <<'EOF'
output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = [for s in aws_subnet.public : s.id]
}

output "security_group_id" {
  value = aws_security_group.k3s_nodes.id
}

output "instance_profile_name" {
  value = length(aws_iam_instance_profile.ec2_profile) > 0 ? aws_iam_instance_profile.ec2_profile[0].name : null
}
EOF
```
### terraform.tfvars
```bash
cat > terraform.tfvars <<'EOF'
project_name        = "quakewatch"
aws_region          = "us-east-1"
vpc_cidr            = "10.42.0.0/16"
az_count            = 2
public_subnet_cidrs = ["10.42.1.0/24", "10.42.2.0/24"]
ssh_allowed_cidr    = "0.0.0.0/0" # change to YOUR_IP/32 later
# we will add key_name, instance_type in Phase B
EOF
```
### Initialize & Apply:
```bash
terraform init
terraform plan -out plan.tfplan
terraform apply plan.tfplan
terraform output
# Expect vpc_id, public_subnet_ids, security_group_id (and instance_profile_name=null)
```

# Cluster Deployment with k3s:

## Add EC2 + Install k3s (control-plane)

### Update `security_groups.tf` (add 6443 + NodePort)
```bash
cat > security_groups.tf <<'EOF'
resource "aws_security_group" "k3s_nodes" {
  name        = "${var.project_name}-k3s-sg"
  description = "Base SG for k3s nodes"
  vpc_id      = aws_vpc.main.id

  # SSH
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  # Kubernetes API (6443)
  ingress {
    description = "K8s API"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  # Intra-cluster
  ingress {
    description = "Intra-VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  # HTTP/HTTPS for apps
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # NodePort range
  ingress {
    description = "K8s NodePort"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-k3s-sg" }
}
EOF
```
### `instances.tf` (create the k3s server)
```bash
cat > instances.tf <<'EOF'
data "aws_ami" "ubuntu_2204" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_instance" "k3s_server" {
  ami                         = data.aws_ami.ubuntu_2204.id
  instance_type               = var.instance_type
  subnet_id                   = element([for s in aws_subnet.public : s.id], 0)
  vpc_security_group_ids      = [aws_security_group.k3s_nodes.id]
  key_name                    = var.key_name
  associate_public_ip_address = true

  user_data = <<-CLOUDINIT
    #cloud-config
    package_update: true
    package_upgrade: true
    packages:
      - curl
      - ufw
    runcmd:
      - curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --write-kubeconfig-mode=0644" sh -
      - systemctl enable k3s
      - systemctl status k3s --no-pager || true
  CLOUDINIT

  tags = { Name = "${var.project_name}-k3s-server" }
}
EOF
```
### Append output for server IP
```bash
cat >> outputs.tf <<'EOF'

output "k3s_server_public_ip" {
  value = aws_instance.k3s_server.public_ip
}
EOF
```
### Add your key + (optional) instance type to `terraform.tfvars`
```bash
cat >> terraform.tfvars <<'EOF'
key_name      = "class11"    # <-- replace if different
instance_type = "t3.small"
EOF
```
### Apply
```bash
terraform fmt -recursive
terraform validate
terraform plan -out plan.tfplan
terraform apply plan.tfplan
terraform output
# Expect k3s_server_public_ip plus the infra outputs
```
### Verify k3s
```bash
IP=$(terraform output -raw k3s_server_public_ip)
ssh -i ~/.ssh/class11.pem ubuntu@$IP 'sudo kubectl get nodes -o wide'
```
### Copy kubeconfig locally:
```bash
scp -i ~/.ssh/class11.pem ubuntu@$IP:/etc/rancher/k3s/k3s.yaml kubeconfig
sed -i "s/127.0.0.1/$IP/g" kubeconfig
export KUBECONFIG=$PWD/kubeconfig
kubectl get nodes
kubectl get pods -A
```

## Remote Access to k3s from WSL
- Once your k3s_server is running and kubectl get nodes works inside the EC2 instance, you need to connect to it securely from your WSL/local machine.
- Open one WSL terminal and run:
```bash
IP=$(terraform output -raw k3s_server_public_ip)
ssh -i ~/.ssh/class11.pem -L 6443:127.0.0.1:6443 ubuntu@$IP
```
- Keep this terminal open — it forwards port 6443 from your local machine to the server securely.

- In your second WSL terminal, point kubectl to the file:
```bash
# Set up local kubeconfig
export KUBECONFIG=$PWD/kubeconfig
# Verify connection
kubectl get nodes -o wide
kubectl get pods -A
# Expected output:
NAME             STATUS   ROLES                  AGE     VERSION
ip-10-42-1-227   Ready    control-plane,master   7h53m   v1.33.5+k3s1

NAMESPACE     NAME                                      READY   STATUS    RESTARTS   AGE
kube-system   coredns-64fd4b4794-9qkkk                  1/1     Running   1          7h
kube-system   traefik-c98fdf6fb-5s42d                   1/1     Running   0          20m
...
```
## Deploy QuakeWatch (Kubernetes Manifests)
```bash
# Set your image
# Use your pushed Docker Hub image
sed -i 's|image: .*|image: sergeytemkin/quakewatch:latest|' k8s/deployment.yaml
# Namespace (idempotent)
kubectl create namespace quakewatch --dry-run=client -o yaml | kubectl apply -f -
# Config & Secrets (idempotent)
kubectl apply -n quakewatch -f k8s/configmap.yaml || true
kubectl apply -n quakewatch -f k8s/secret.yaml    || true
# Deployment
# (uses readiness/liveness probes on /health and resources tuned for small node)
kubectl apply -n quakewatch -f k8s/deployment.yaml
# check rollout
kubectl -n quakewatch get deploy
kubectl -n quakewatch get po -w
```
### Service (ClusterIP)
```bash
cat > k8s/service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: quakewatch
  namespace: quakewatch
spec:
  selector:
    app: quakewatch
  ports:
    - name: http
      port: 80
      targetPort: 5000
  type: ClusterIP
EOF

kubectl apply -f k8s/service.yaml
kubectl -n quakewatch get svc quakewatch
```
### Ingress (Traefik on port 80)
```bash
cat > k8s/ingress.yaml <<'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: quakewatch
  namespace: quakewatch
spec:
  ingressClassName: traefik
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: quakewatch
                port:
                  number: 80
EOF

kubectl apply -f k8s/ingress.yaml
kubectl -n quakewatch get ingress quakewatch
```
### NodePort for quick external testing
```bash
cat > k8s/nodeport.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: quakewatch-nodeport
  namespace: quakewatch
spec:
  selector:
    app: quakewatch
  type: NodePort
  ports:
    - name: http
      port: 80
      targetPort: 5000
      nodePort: 30080
EOF

kubectl apply -f k8s/nodeport.yaml
kubectl -n quakewatch get svc quakewatch-nodeport
```
### Verify resources
```bash
kubectl -n quakewatch get deploy,po,svc,ingress
# expected example:
deployment.apps/quakewatch   2/2   2   2   20m
pod/quakewatch-...           1/1   Running
service/quakewatch           ClusterIP 80/TCP
ingress/quakewatch           traefik  ADDRESS: <node-ip>  PORTS: 80
```
### Test externally
- Make sure your SSH tunnel shell is open (from earlier step):
`ssh -i ~/.ssh/class11.pem -L 6443:127.0.0.1:6443 ubuntu@$IP`
```bash
IP=$(terraform -chdir=phase5/terraform output -raw k3s_server_public_ip)
# via Ingress (Traefik, port 80)
curl -I http://$IP/
# via NodePort (fallback)
curl -I http://$IP:30080/
# expected:
HTTP/1.1 200 OK
Server: gunicorn
Content-Type: text/html; charset=utf-8
```
### Troubleshooting quickies
```bash
# Wait for Traefik to pick up the new Ingress
kubectl -n kube-system get po -l app.kubernetes.io/name=traefik
kubectl -n quakewatch describe ingress quakewatch | sed -n '1,150p'
# Check service endpoints
kubectl -n quakewatch get endpoints quakewatch -o wide
```






