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

variable "subnet_address_count" {
  description = <<-EOT
    Number of IPv4 addresses to allocate in the new subnet.
    IBM Cloud carves a matching CIDR automatically from the zone's
    default address prefix — avoids CIDR-mismatch errors.
    Must be a power of 2 (e.g. 256 = /24, 512 = /23).
  EOT
  type        = number
  default     = 256
}

# ── Existing resource names (leave empty to create new) ──────────
variable "existing_vpc_name" {
  description = <<-EOT
    Name of an existing IBM Cloud VPC to reuse.
    Leave empty ("") to create a new VPC named <project>-<env>-vpc.
  EOT
  type        = string
  default     = ""
}

variable "existing_subnet_name" {
  description = <<-EOT
    Name of an existing subnet inside the VPC to reuse.
    Leave empty ("") to create a new subnet in var.ibm_zone.
  EOT
  type        = string
  default     = ""
}

variable "ssh_public_key" {
  description = "SSH public key material (from Vault) to register as an IBM Cloud SSH key"
  type        = string
  sensitive   = true
}
