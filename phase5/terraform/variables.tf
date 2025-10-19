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

# optional (we disabled IAM earlier)
variable "enable_ssm" {
  type        = bool
  default     = false
  description = "Create EC2 IAM role/profile with SSM (needs IAM perms)"
}

variable "key_name" {
  type        = string
  description = "Existing AWS EC2 key pair name"
}

variable "instance_type" {
  type        = string
  default     = "t3.small"
  description = "EC2 size for k3s server"
}
