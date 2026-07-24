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

variable "vpc_id" {
  description = "ID of the VPC in which to create the ALB"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs across which the ALB is deployed"
  type        = list(string)
}

variable "alb_sg_id" {
  description = "ID of the security group to attach to the ALB"
  type        = string
}

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
