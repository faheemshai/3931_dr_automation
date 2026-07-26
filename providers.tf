# ---------------------------------------------------------------
# providers.tf
#
# Bootstrap order (Terraform resolves this automatically):
#
#   1. vault provider   → initialises from vault_address + vault_token
#                         (both come from env vars / tfvars — no IBM dep)
#   2. data.vault_kv_secret_v2.bootstrap
#                       → reads IBM API key from Vault KV at plan time
#   3. locals.ibm_api_key
#                       → extracts the key from the Vault response
#   4. ibm provider     → initialises with the key from Vault
#
# The vault provider is declared FIRST so Terraform can satisfy the
# data source dependency before configuring the ibm provider.
# ---------------------------------------------------------------

# ── 1. Vault provider (bootstraps from env vars) ──────────────────
provider "vault" {
  address   = var.vault_address
  token     = var.vault_token
  namespace = var.vault_namespace != "" ? var.vault_namespace : null
}

# ── 2. Read IBM API key from Vault at plan/apply time ─────────────
# This data source runs against the already-initialised vault provider.
# It reads the SAME secret path used by the vault_integration module so
# there is a single source of truth in Vault.
data "vault_kv_secret_v2" "ibm_credentials" {
  mount = var.vault_mount_path
  name  = var.vault_secret_path
}

# ── 3. Extract the API key into a local ───────────────────────────
locals {
  ibm_api_key = data.vault_kv_secret_v2.ibm_credentials.data["ibm_api_key"]
}

# ── 4. IBM Cloud provider — key sourced entirely from Vault ───────
provider "ibm" {
  region           = var.ibm_region
  ibmcloud_api_key = local.ibm_api_key
}
