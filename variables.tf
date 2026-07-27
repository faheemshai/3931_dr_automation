# ---------------------------------------------------------------
# Root-level variables
# Every variable used by any child module is declared here so
# operators have a single place to review and override inputs.
# ---------------------------------------------------------------

# ── IBM Cloud General ────────────────────────────────────────────
variable "ibm_region" {
  description = "IBM Cloud region to deploy into (e.g. eu-de)"
  type        = string
  default     = "eu-de"
}

variable "ibm_zone" {
  description = "IBM Cloud zone inside the region (e.g. eu-de-2)"
  type        = string
  default     = "eu-de-2"
}

variable "environment" {
  description = "Deployment environment label used in resource naming (prod / staging / dev)"
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["prod", "staging", "dev"], var.environment)
    error_message = "environment must be one of: prod, staging, dev."
  }
}

variable "project" {
  description = "Short project name used as a prefix in all resource names"
  type        = string
  default     = "ent-demo"
}

# ── Networking ───────────────────────────────────────────────────
variable "subnet_cidr" {
  description = "CIDR block for the subnet in eu-de-2 (used when not relying on default VPC subnet)"
  type        = string
  default     = "10.240.2.0/24"
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
  description = "IBM Cloud VSI profile (e.g. bx2-2x8 = 2 vCPU / 8 GB RAM Flex)"
  type        = string
  default     = "bx2-2x8"
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
  description = "Vault server URL (e.g. https://vault.example.com:8200)"
  type        = string
  default     = "https://vault.example.com:8200"
}

variable "vault_namespace" {
  description = "Vault Enterprise namespace (e.g. eelab/Catalyst)"
  type        = string
  default     = "eelab/Catalyst"
}

variable "vault_mount_path" {
  description = "KV mount name in Vault (e.g. kv)"
  type        = string
  default     = "kv"
}

variable "vault_secret_path" {
  description = "Secret path within the KV mount (e.g. terraform → full path kv/terraform)"
  type        = string
  default     = "terraform"
}
