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

variable "ssh_allowed_cidr" {
  description = "CIDR block allowed to SSH (port 22) to VSI instances"
  type        = string
}

variable "app_port" {
  description = "TCP port the web application listens on"
  type        = number
  default     = 80
}
