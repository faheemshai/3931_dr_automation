# ---------------------------------------------------------------
# Root-level variables
# Every variable used by any child module is declared here so
# operators have a single place to review and override inputs.
# ---------------------------------------------------------------

# ── General ──────────────────────────────────────────────────────
variable "aws_region" {
  description = "AWS region to deploy into (e.g. us-east-1)"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment label used in resource naming (prod / staging / dev)"
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["prod", "staging", "dev"], var.environment)
    error_message = "environment must be one of: prod, staging, dev."
  }
}

variable "project" {
  description = "Short project name used as a prefix in all resource names"
  type        = string
  default     = "ent-demo"
}

# ── VPC ──────────────────────────────────────────────────────────
variable "vpc_cidr" {
  description = "Primary CIDR block for the VPC (e.g. 10.0.0.0/16)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets — one per AZ (ALB, NAT GW)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets — one per AZ (EC2 ASG)"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "availability_zones" {
  description = "List of AZs to deploy subnets into (must align with subnet CIDR lists)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# ── Security Groups ───────────────────────────────────────────────
variable "bastion_cidr" {
  description = "CIDR block allowed to SSH (port 22) to application instances — restrict to your bastion / VPN range"
  type        = string
  default     = "10.0.0.0/8"
}

# ── ALB ──────────────────────────────────────────────────────────
variable "health_check_path" {
  description = "HTTP path the ALB target group uses for instance health checks"
  type        = string
  default     = "/health"
}

variable "app_port" {
  description = "TCP port the application process listens on inside EC2 instances"
  type        = number
  default     = 8080
}

# ── EC2 ──────────────────────────────────────────────────────────
variable "instance_type" {
  description = "EC2 instance type for the Auto Scaling Group (e.g. t3.micro, m6i.large)"
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "AMI ID for EC2 instances — defaults to Amazon Linux 2023 in us-east-1"
  type        = string
  default     = "ami-0c101f26f147fa7fd" # Amazon Linux 2023 us-east-1
}

variable "desired_capacity" {
  description = "Desired number of EC2 instances in the Auto Scaling Group"
  type        = number
  default     = 2
}

variable "min_size" {
  description = "Minimum number of instances the ASG will maintain"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of instances the ASG may scale out to"
  type        = number
  default     = 4
}

# ── Vault ─────────────────────────────────────────────────────────
variable "vault_address" {
  description = "Full URL of the Vault server (e.g. https://vault.example.com:8200)"
  type        = string
  default     = "http://127.0.0.1:8200"
}

variable "vault_token" {
  description = "Vault token for Terraform authentication. Set via TF_VAR_vault_token env var — never commit this value."
  type        = string
  sensitive   = true
  default     = "" # Override with: export TF_VAR_vault_token=<token>
}

variable "vault_namespace" {
  description = "Vault Enterprise namespace (leave empty for OSS / HCP Vault Dedicated)"
  type        = string
  default     = ""
}

variable "vault_mount_path" {
  description = "KV v2 secrets engine mount path inside Vault (e.g. kv/ent-demo)"
  type        = string
  default     = "kv/ent-demo"
}

variable "vault_secret_path" {
  description = "Path within the KV mount that holds the application credentials (e.g. app/credentials)"
  type        = string
  default     = "app/credentials"
}
