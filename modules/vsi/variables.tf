# ---------------------------------------------------------------
# modules/vsi/variables.tf
# ---------------------------------------------------------------

variable "project" {
  description = "Short project name used as a prefix in all resource names"
  type        = string
}

variable "environment" {
  description = "Deployment environment label (prod / staging / dev / sNN)"
  type        = string
}

variable "ibm_resource_group_id" {
  description = "IBM Cloud resource group ID — VSIs and Floating IPs are placed in this group"
  type        = string
}

variable "ibm_region" {
  description = "IBM Cloud region (e.g. us-south) — passed into user_data template"
  type        = string
}

variable "ibm_zone" {
  description = "IBM Cloud zone to launch VSIs into (e.g. us-south-1)"
  type        = string
}

variable "vsi_count" {
  description = "Number of VSI instances to create"
  type        = number
  default     = 1
}

variable "vsi_profile" {
  description = "IBM Cloud VSI profile (e.g. cx2-2x4 = 2 vCPU / 4 GB)"
  type        = string
}

variable "image_id" {
  description = "IBM Cloud image ID (UUID) for the VSI — from Packer golden image"
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
  description = "ID of the IBM Cloud SSH key (registered from Vault public key)"
  type        = string
}

variable "vsi_sg_id" {
  description = "ID of the VSI security group to attach to each instance"
  type        = string
}

variable "app_port" {
  description = "TCP port the web application listens on"
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
