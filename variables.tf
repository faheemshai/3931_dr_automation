# ---------------------------------------------------------------
# Root-level variables
# ---------------------------------------------------------------

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment label (prod / staging / dev)"
  type        = string
  default     = "prod"
}

variable "project" {
  description = "Short project name used in resource naming"
  type        = string
  default     = "ent-demo"
}

# ── VPC ──────────────────────────────────────────────────────────
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "availability_zones" {
  description = "AZs to deploy subnets into"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# ── EC2 ──────────────────────────────────────────────────────────
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "AMI ID for EC2 instances (Amazon Linux 2023 default)"
  type        = string
  default     = "ami-0c101f26f147fa7fd" # Amazon Linux 2023 us-east-1
}

variable "desired_capacity" {
  description = "Desired number of EC2 instances in the ASG"
  type        = number
  default     = 2
}

variable "min_size" {
  description = "Minimum number of instances in the ASG"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of instances in the ASG"
  type        = number
  default     = 4
}

# ── Vault ─────────────────────────────────────────────────────────
variable "vault_address" {
  description = "Address of the Vault server (e.g. https://vault.example.com:8200)"
  type        = string
  default     = "http://127.0.0.1:8200"
}

variable "vault_token" {
  description = "Vault token used by Terraform (use env var TF_VAR_vault_token or Vault agent)"
  type        = string
  sensitive   = true
  default     = "" # Set via TF_VAR_vault_token or .auto.tfvars (never commit)
}

variable "vault_mount_path" {
  description = "KV v2 mount path inside Vault"
  type        = string
  default     = "kv/ent-demo"
}

variable "vault_secret_path" {
  description = "Path inside the KV mount that holds app credentials"
  type        = string
  default     = "app/credentials"
}
