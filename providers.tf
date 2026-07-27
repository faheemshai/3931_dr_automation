# ---------------------------------------------------------------
# providers.tf
#
# Vault Enterprise + Terraform Enterprise Dynamic Credentials
# ═══════════════════════════════════════════════════════════
#
# How TFE Dynamic Credentials work for the Vault provider:
#
#   When TFC_VAULT_PROVIDER_AUTH=true is set as a TFE workspace env var,
#   TFE automatically:
#     1. Mints a short-lived workload-identity JWT for the run
#     2. Exchanges it with Vault for a scoped token (via JWT auth)
#     3. Sets VAULT_TOKEN in the run environment
#
#   The vault provider below picks up VAULT_TOKEN automatically —
#   NO auth_login_jwt block, NO explicit token argument needed.
#   Only address and namespace are set here so the provider knows
#   where to connect.
#
# Required TFE workspace environment variables (set in TFE UI):
#   TFC_VAULT_PROVIDER_AUTH = true
#   TFC_VAULT_ADDR          = https://vault.example.com:8200
#   TFC_VAULT_NAMESPACE     = eelab/Catalyst
#   TFC_VAULT_RUN_ROLE      = <your-vault-jwt-role-name>
# ---------------------------------------------------------------

# ── Vault provider — address + namespace only ─────────────────────
# TFE injects VAULT_TOKEN automatically when TFC_VAULT_PROVIDER_AUTH=true.
provider "vault" {
  address   = var.vault_address
  namespace = var.vault_namespace
  # token is set automatically by TFE via VAULT_TOKEN env var — do not set here
}

# ── Read IBM API key + SSH public key from Vault KV ───────────────
data "vault_kv_secret_v2" "ibm_credentials" {
  mount = var.vault_mount_path   # kv
  name  = var.vault_secret_path  # terraform
}

# ── Extract IBM API key into a local ─────────────────────────────
# NOTE: ssh_public_key flows separately:
#   module.vault_integration → output ssh_public_key
#   → module.networking → ibm_is_ssh_key
locals {
  ibm_api_key = data.vault_kv_secret_v2.ibm_credentials.data["ibm_api_key"]
}
  
# ── IBM Cloud provider — API key sourced from Vault KV ────────────
provider "ibm" {
  region           = var.ibm_region
  ibmcloud_api_key = local.ibm_api_key
}
