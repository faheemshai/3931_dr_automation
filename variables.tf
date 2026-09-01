# ---------------------------------------------------------------
# variables.tf  –  LAB-3931 DR Automation
# ---------------------------------------------------------------

# ── Project identity ─────────────────────────────────────────────
variable "project" {
  description = "Short project name used as prefix in all resource names"
  type        = string
  default     = "lab3931"
}

variable "environment" {
  description = "Deployment environment label (demo / prod / staging)"
  type        = string
  default     = "demo"

  validation {
    condition     = contains(["demo", "prod", "staging", "dev"], var.environment)
    error_message = "environment must be one of: demo, prod, staging, dev."
  }
}

# ── PRIMARY region — us-south ────────────────────────────────────
variable "ibm_region_primary" {
  description = "IBM Cloud primary region"
  type        = string
  default     = "us-south"
}

variable "ibm_zone_primary" {
  description = "IBM Cloud primary availability zone"
  type        = string
  default     = "us-south-1"
}

variable "existing_vpc_name_primary" {
  description = "Existing VPC name in us-south. Leave empty to create new."
  type        = string
  default     = "vpc-eelab"
}

variable "existing_subnet_name_primary" {
  description = "Existing subnet name in us-south. Leave empty to create new."
  type        = string
  default     = "sn-20260511-1"
}

# ── DR region — eu-de ─────────────────────────────────────────────
variable "ibm_region_dr" {
  description = "IBM Cloud DR region"
  type        = string
  default     = "eu-de"
}

variable "ibm_zone_dr" {
  description = "IBM Cloud DR availability zone"
  type        = string
  default     = "eu-de-2"
}

variable "existing_vpc_name_dr" {
  description = "Existing VPC name in eu-de. Leave empty to create new."
  type        = string
  default     = ""
}

variable "existing_subnet_name_dr" {
  description = "Existing subnet name in eu-de. Leave empty to create new."
  type        = string
  default     = ""
}

# ── Golden images from Packer ────────────────────────────────────
# These can be manually supplied, or they resolve dynamically from
# the hcp_packer_artifact data source if left as default/empty.
variable "golden_image_id_us_south" {
  description = "IBM Cloud image ID (r006-...) of the Packer-built golden image in us-south. Sourced from Vault/Packer."
  type        = string
  default     = ""
}

variable "golden_image_id_eu_de" {
  description = "IBM Cloud image ID (r006-...) of the Packer-built golden image in eu-de. Sourced from Vault/Packer."
  type        = string
  default     = ""
}

# ── Networking ───────────────────────────────────────────────────
variable "subnet_address_count" {
  description = "IPv4 addresses per subnet (256 = /24). IBM Cloud picks CIDR automatically."
  type        = number
  default     = 256
}

# ── Security ─────────────────────────────────────────────────────
variable "ssh_allowed_cidr" {
  description = "CIDR allowed to SSH — restrict to your bastion / VPN CIDR in production"
  type        = string
  default     = "10.0.0.0/8"
}

# ── Application ──────────────────────────────────────────────────
variable "app_port" {
  description = "TCP port the app listens on inside the VSI"
  type        = number
  default     = 80
}

variable "health_check_path" {
  description = "LB health check HTTP path"
  type        = string
  default     = "/"
}

# ── VSI ──────────────────────────────────────────────────────────
variable "vsi_count" {
  description = "Number of VSIs per region"
  type        = number
  default     = 1
}

variable "vsi_profile" {
  description = "IBM Cloud VSI profile"
  type        = string
  default     = "cx2-2x4"
}

# ── Vault Enterprise ─────────────────────────────────────────────
variable "vault_address" {
  description = "Vault server URL"
  type        = string
  default     = "https://vault-cluster-public-vault-564045ad.ea599dfb.z1.hashicorp.cloud:8200"
}

variable "vault_namespace" {
  description = "Vault Enterprise namespace"
  type        = string
  default     = "admin"
}

variable "vault_mount_path" {
  description = "KV v2 mount name in Vault"
  type        = string
  default     = "kv"
}

variable "vault_secret_path" {
  description = "Secret path within the KV mount"
  type        = string
  default     = "IBM_cloud"
}

# ── Legacy / backwards compat ────────────────────────────────────
# Kept so existing TFE workspace variables don't break.
variable "ibm_region" {
  description = "Legacy single-region variable — use ibm_region_primary instead"
  type        = string
  default     = "us-south"
}

variable "ibm_zone" {
  description = "Legacy single-region variable — use ibm_zone_primary instead"
  type        = string
  default     = "us-south-1"
}

variable "image_name" {
  description = "Legacy image variable — use golden_image_name_us_south instead"
  type        = string
  default     = "rhel92-golden-20260830091707-us-south"
}
