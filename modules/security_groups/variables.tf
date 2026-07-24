# ---------------------------------------------------------------
# modules/security_groups/variables.tf
# ---------------------------------------------------------------

variable "project" {
  description = "Short project name used as a prefix in all resource names"
  type        = string
}

variable "environment" {
  description = "Deployment environment label (prod / staging / dev)"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC in which to create the security groups"
  type        = string
}

variable "bastion_cidr" {
  description = "CIDR block allowed to SSH (port 22) to application instances — restrict to your bastion / VPN range"
  type        = string
  default     = "10.0.0.0/8"
}
