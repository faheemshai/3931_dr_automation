# ---------------------------------------------------------------
# modules/ec2/variables.tf
# ---------------------------------------------------------------

variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "ami_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "app_sg_id" {
  type = string
}

variable "target_group_arn" {
  type = string
}

variable "desired_capacity" {
  type = number
}

variable "min_size" {
  type = number
}

variable "max_size" {
  type = number
}

# ── Credentials supplied at runtime (from Vault module) ───────────
variable "db_username" {
  description = "Database username injected from Vault"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Database password injected from Vault"
  type        = string
  sensitive   = true
}

variable "app_api_key" {
  description = "Third-party API key injected from Vault"
  type        = string
  sensitive   = true
}
