# ---------------------------------------------------------------
# modules/alb/variables.tf
# ---------------------------------------------------------------

variable "project" {
  description = "Short project name used as a prefix in all resource names"
  type        = string
}

variable "environment" {
  description = "Deployment environment label (prod / staging / dev)"
  type        = string
}

variable "ibm_region" {
  description = "IBM Cloud region (e.g. eu-de)"
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet in which to place the load balancer"
  type        = string
}

variable "app_port" {
  description = "TCP port the application listens on inside VSI instances"
  type        = number
  default     = 80
}

variable "ibm_resource_group_id" {
  description = "IBM Cloud resource group ID — the LB is created in this group"
  type        = string
}

variable "health_check_path" {
  description = "HTTP path the LB health monitor uses for member health checks"
  type        = string
  default     = "/"
}
