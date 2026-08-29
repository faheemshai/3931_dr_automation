# ---------------------------------------------------------------
# Root-level variables
# Every variable used by any child module is declared here so
# operators have a single place to review and override inputs.
# ---------------------------------------------------------------

# ── IBM Cloud General ────────────────────────────────────────────
variable "ibm_region" {
  description = "IBM Cloud region — eu-de (Frankfurt)"
  type        = string
  default     = "eu-de"
}

variable "ibm_zone" {
  description = "IBM Cloud availability zone — eu-de-2"
  type        = string
  default     = "eu-de-2"
}

variable "environment" {
  description = "Deployment environment label used in resource naming (demo / prod / staging / dev)"
  type        = string
  default     = "demo"

  validation {
    condition     = contains(["demo", "prod", "staging", "dev"], var.environment)
    error_message = "environment must be one of: demo, prod, staging, dev."
  }
}

variable "project" {
  description = "Short project name used as a prefix in all resource names"
  type        = string
  default     = "ent-demo"
}

# ── Networking ───────────────────────────────────────────────────
variable "existing_vpc_name" {
  description = "Name of an existing IBM Cloud VPC to reuse. Leave empty ('') to create a new one in eu-de."
  type        = string
  default     = ""
}

variable "existing_subnet_name" {
  description = "Name of an existing subnet to reuse. Leave empty ('') to create a new one in eu-de-2."
  type        = string
  default     = ""
}

variable "subnet_address_count" {
  description = <<-EOT
    Number of IPv4 addresses for the new subnet when no existing_subnet_name is set.
    IBM Cloud auto-carves a valid CIDR from the zone's default address prefix.
    Must be a power of 2 (256 = /24, 512 = /23, 1024 = /22).
  EOT
  type        = number
  default     = 256
}

# ── Security / SSH ────────────────────────────────────────────────
variable "ssh_allowed_cidr" {
  description = "CIDR block allowed to SSH (port 22) to VSI instances — restrict to your bastion / VPN range"
  type        = string
  default     = "10.0.0.0/8"
}

# ── Load Balancer / Web App ───────────────────────────────────────
variable "app_port" {
  description = "TCP port the web application listens on inside VSI instances"
  type        = number
  default     = 80
}

variable "health_check_path" {
  description = "HTTP path the LB pool member health monitor uses"
  type        = string
  default     = "/"
}

# ── VSI ──────────────────────────────────────────────────────────
variable "vsi_count" {
  description = "Number of VSI instances to create (fixed, not ASG)"
  type        = number
  default     = 2
}

variable "vsi_profile" {
  description = "IBM Cloud VSI profile (bxf-2x8 = Flex | 2 vCPU / 8 GB RAM)"
  type        = string
  default     = "bxf-2x8"
}

variable "image_name" {
  description = "IBM Cloud stock image name for the VSI"
  type        = string
  default     = "ibm-centos-stream-9-amd64-17"
}

# ── Vault Enterprise + TFE Dynamic Credentials ───────────────────
# TFE sets VAULT_TOKEN automatically when TFC_VAULT_PROVIDER_AUTH=true.
# vault_address and vault_namespace are the only provider arguments needed.
# vault_jwt_auth_path and vault_jwt_role are NOT needed — TFE handles auth.

variable "vault_address" {
  description = "Vault server URL — matches TFC_DEFAULT_VAULT_ADDR in TFE credential set"
  type        = string
  default     = "https://vault-cluster-public-vault-564045ad.ea599dfb.z1.hashicorp.cloud:8200"
}

variable "vault_namespace" {
  description = "Vault Enterprise namespace — matches TFC_VAULT_NAMESPACE in TFE credential set"
  type        = string
  default     = "admin"
}

variable "vault_mount_path" {
  description = "KV mount name in Vault (e.g. kv)"
  type        = string
  default     = "kv"
}

variable "vault_secret_path" {
  description = "Secret path within the KV mount (e.g. IBM_cloud → full path kv/IBM_cloud)"
  type        = string
  default     = "IBM_cloud"
}
