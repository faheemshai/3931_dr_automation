# ---------------------------------------------------------------
# modules/ec2/variables.tf
# ---------------------------------------------------------------

variable "project" {
  description = "Short project name used as a prefix in all resource names"
  type        = string
}

variable "environment" {
  description = "Deployment environment label (prod / staging / dev)"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for EC2 instances"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type (e.g. t3.micro, m6i.large)"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs into which the ASG launches instances"
  type        = list(string)
}

variable "app_sg_id" {
  description = "ID of the application security group to attach to EC2 instances"
  type        = string
}

variable "target_group_arn" {
  description = "ARN of the ALB target group to register ASG instances with"
  type        = string
}

variable "desired_capacity" {
  description = "Desired number of EC2 instances in the Auto Scaling Group"
  type        = number
}

variable "min_size" {
  description = "Minimum number of instances the ASG will maintain"
  type        = number
}

variable "max_size" {
  description = "Maximum number of instances the ASG may scale out to"
  type        = number
}

# ── Credentials supplied at runtime from Vault ───────────────────
variable "db_username" {
  description = "Database username — injected from Vault KV secret"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Database password — injected from Vault KV secret"
  type        = string
  sensitive   = true
}

variable "app_api_key" {
  description = "Third-party API key — injected from Vault KV secret"
  type        = string
  sensitive   = true
}
