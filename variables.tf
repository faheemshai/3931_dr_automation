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
  description = "Deployment environment label (demo / prod / staging / dev / sNN for student workspaces)"
  type        = string
  default     = "demo"
}

# ── IBM Cloud resource group ──────────────────────────────────────
variable "ibm_resource_group_id" {
  description = "IBM Cloud resource group ID. VSIs, SSH keys, and Packer images are placed here."
  type        = string
  default     = "90733208e12b46eda9c4fbc130b8e426"
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

# ID-based lookup (preferred — set when you have the resource ID)
variable "existing_vpc_id_primary" {
  description = "Existing VPC ID in us-south (r006-...). Takes precedence over existing_vpc_name_primary when set."
  type        = string
  default     = "r006-76dee245-0417-4682-951e-2b1d149a7639"
}

variable "existing_subnet_id_primary" {
  description = "Existing subnet ID in us-south (0717-...). Takes precedence over existing_subnet_name_primary when set."
  type        = string
  default     = "0717-c20d5d2d-6216-4b99-88d7-8b441ef20a9e"
}

# Name-based lookup fallback (used only when ID variables are empty)
variable "existing_vpc_name_primary" {
  description = "Existing VPC name in us-south. Used only when existing_vpc_id_primary is empty."
  type        = string
  default     = ""
}

variable "existing_subnet_name_primary" {
  description = "Existing subnet name in us-south. Used only when existing_subnet_id_primary is empty."
  type        = string
  default     = ""
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

# ID-based lookup for DR (preferred)
variable "existing_vpc_id_dr" {
  description = "Existing VPC ID in eu-de (r010-...). Takes precedence over existing_vpc_name_dr when set."
  type        = string
  default     = "r010-75fc4ba7-8a56-4a42-baaa-b6691a7f24ac"
}

variable "existing_subnet_id_dr" {
  description = "Existing subnet ID in eu-de (02b7-...). Takes precedence over existing_subnet_name_dr when set."
  type        = string
  default     = "02b7-df5e6a98-fa9c-4e87-b67c-057d360b62ba"
}

# Name-based lookup fallback
variable "existing_vpc_name_dr" {
  description = "Existing VPC name in eu-de. Used only when existing_vpc_id_dr is empty."
  type        = string
  default     = ""
}

variable "existing_subnet_name_dr" {
  description = "Existing subnet name in eu-de. Used only when existing_subnet_id_dr is empty."
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

# ── DR region deployment control ──────────────────────────────────
variable "DR_infra" {
  description = "Set to true to deploy all infrastructure in the DR region (eu-de). Set to false to run us-south primary only."
  type        = bool
  default     = false
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
