# ---------------------------------------------------------------
# modules/security_groups/variables.tf
# ---------------------------------------------------------------

variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "bastion_cidr" {
  description = "CIDR allowed to SSH to app instances (bastion / VPN range)"
  type        = string
  default     = "10.0.0.0/8"
}
