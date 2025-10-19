project_name        = "quakewatch"
aws_region          = "us-east-1"
vpc_cidr            = "10.42.0.0/16"
az_count            = 2
public_subnet_cidrs = ["10.42.1.0/24", "10.42.2.0/24"]
ssh_allowed_cidr    = "0.0.0.0/0" # change to YOUR_IP/32 for security
key_name            = "class11"
