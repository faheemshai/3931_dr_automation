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

variable "ibmcloud_api_key" {
  description = "IBM Cloud API key. Prefer setting via IC_API_KEY env var."
  type        = string
  sensitive   = true
  default     = "" # Override with: export IC_API_KEY=<key>
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

# ── Vault ─────────────────────────────────────────────────────────
variable "vault_address" {
  description = "Full URL of the Vault server (e.g. https://vault.example.com:8200)"
  type        = string
  default     = "http://127.0.0.1:8200"
}

variable "vault_token" {
  description = "Vault token for Terraform authentication. Set via TF_VAR_vault_token env var — never commit this value."
  type        = string
  sensitive   = true
  default     = "" # Override with: export TF_VAR_vault_token=<token>
}

variable "vault_namespace" {
  description = "Vault Enterprise namespace (leave empty for OSS / HCP Vault Dedicated)"
  type        = string
  default     = ""
}

variable "vault_mount_path" {
  description = "KV v2 secrets engine mount path inside Vault (e.g. kv/ent-demo)"
  type        = string
  default     = "kv/ent-demo"
}

variable "vault_secret_path" {
  description = "Path within the KV mount that holds the SSH key pair (e.g. ssh/keypair)"
  type        = string
  default     = "ssh/keypair"
}
