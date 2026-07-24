# ---------------------------------------------------------------
# modules/vpc/variables.tf
# ---------------------------------------------------------------

variable "project" {
  description = "Short project name used as a prefix in all resource names"
  type        = string
}

variable "environment" {
  description = "Deployment environment label (prod / staging / dev)"
  type        = string
}

variable "vpc_cidr" {
  description = "Primary CIDR block for the VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets — one per AZ"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets — one per AZ"
  type        = list(string)
}

variable "availability_zones" {
  description = "List of AZs to spread subnets across (must align with subnet CIDR lists)"
  type        = list(string)
}
