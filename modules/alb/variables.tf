# ---------------------------------------------------------------
# modules/alb/variables.tf
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

variable "public_subnet_ids" {
  type = list(string)
}

variable "alb_sg_id" {
  type = string
}

variable "health_check_path" {
  description = "HTTP path for ALB target group health check"
  type        = string
  default     = "/health"
}

variable "app_port" {
  description = "Port the application listens on"
  type        = number
  default     = 8080
}
