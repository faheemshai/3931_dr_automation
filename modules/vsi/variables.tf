# ---------------------------------------------------------------
# modules/vsi/variables.tf
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
  description = "IBM Cloud region (e.g. eu-de) — passed into user_data template for display"
  type        = string
}

variable "ibm_zone" {
  description = "IBM Cloud zone to launch VSIs into (e.g. eu-de-2)"
  type        = string
}

variable "vsi_count" {
  description = "Number of VSI instances to create"
  type        = number
  default     = 2
}

variable "vsi_profile" {
  description = "IBM Cloud VSI profile (e.g. bxf-2x8 = Flex | 2 vCPU / 8 GB)"
  type        = string
}

variable "image_id" {
  description = "IBM Cloud image ID (UUID) for the VSI"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC in which to create the VSIs"
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet to attach the VSI primary network interface to"
  type        = string
}

variable "ssh_key_id" {
  description = "ID of the IBM Cloud SSH key (public key loaded from Vault)"
  type        = string
}

variable "lb_sg_id" {
  description = "ID of the load balancer security group (passed through for dependency ordering)"
  type        = string
}

variable "vsi_sg_id" {
  description = "ID of the VSI security group to attach to each instance"
  type        = string
}

variable "lb_id" {
  description = "ID of the IBM Cloud Application Load Balancer"
  type        = string
}

variable "lb_pool_id" {
  description = "ID of the LB back-end pool to register VSIs into"
  type        = string
}

variable "app_port" {
  description = "TCP port the web application listens on (used for pool member registration)"
  type        = number
  default     = 80
}

variable "dr_role" {
  description = "DR role tag: 'primary' or 'dr' — used by failover scripts to target VSIs"
  type        = string
  default     = "primary"
}

variable "dr_pair" {
  description = "DR pair identifier, e.g. 'us-south-eu-de' — ties primary and DR together"
  type        = string
  default     = "us-south-eu-de"
}
