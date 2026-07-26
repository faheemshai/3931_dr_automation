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

variable "ibm_region" {
  description = "IBM Cloud region (e.g. eu-de)"
  type        = string
}

variable "ibm_zone" {
  description = "IBM Cloud zone inside the region (e.g. eu-de-2)"
  type        = string
}

variable "subnet_cidr" {
  description = "IPv4 CIDR block for the subnet in the target zone"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key material (from Vault) to register as an IBM Cloud SSH key"
  type        = string
  sensitive   = true
}
