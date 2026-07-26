# ---------------------------------------------------------------
# providers.tf
#
# Vault Enterprise + Terraform Enterprise Dynamic Credentials
# ═══════════════════════════════════════════════════════════
#
# How TFE Dynamic Credentials work (Workload Identity / JWT auth):
#
#   1. TFE injects two env vars into every plan/apply run automatically:
#        TFC_VAULT_PROVIDER_AUTH = "true"
#        TFC_VAULT_ADDR          = "https://vault.example.com:8200"
#        TFC_VAULT_NAMESPACE     = "admin/ent-demo"   (Enterprise)
#        TFC_VAULT_RUN_ROLE      = "tfe-ibm-demo"     (JWT role name)
#        VAULT_TOKEN             – NOT used / NOT needed
#
#   2. The vault provider below performs a JWT login against the
#      Vault JWT auth method, exchanging the TFE workload identity
#      JWT for a short-lived Vault token scoped to the named role.
#      No static token ever exists.
#
#   3. With that short-lived token the provider reads KV secrets
#      (IBM API key, SSH public key) and the ibm provider is
#      initialised with the API key extracted from Vault KV.
#
# Required Vault-side setup (one-time, by Vault admin):
#   vault auth enable -path=jwt jwt
#   vault write auth/jwt/config \
#     oidc_discovery_url="https://<TFE_HOSTNAME>/.well-known/openid-configuration" \
#     bound_issuer="https://<TFE_HOSTNAME>"
#   vault write auth/jwt/role/tfe-ibm-demo \
#     role_type="jwt" \
#     bound_audiences="<TFE_VAULT_AUDIENCE>" \
#     user_claim="terraform_full_workspace" \
#     token_policies="ent-demo-policy" \
#     token_ttl="20m" \
#     token_max_ttl="30m"
#
# Required TFE workspace environment variables (set in TFE UI / API):
#   TFC_VAULT_PROVIDER_AUTH = true
#   TFC_VAULT_ADDR          = https://vault.example.com:8200
#   TFC_VAULT_NAMESPACE     = admin/ent-demo          (Enterprise)
#   TFC_VAULT_RUN_ROLE      = tfe-ibm-demo
# ---------------------------------------------------------------

# ── Vault provider — JWT Dynamic Credentials (TFE Workload Identity)
# The provider reads TFC_VAULT_ADDR and TFC_VAULT_NAMESPACE from the
# environment automatically.  We only supply the auth_login_jwt block
# to tell it WHICH JWT role to use and where the JWT auth method is mounted.
provider "vault" {
  # address and namespace are sourced from:
  #   TFC_VAULT_ADDR      → VAULT_ADDR   (set by TFE automatically)
  #   TFC_VAULT_NAMESPACE → VAULT_NAMESPACE (Enterprise, set by TFE)
  # Do NOT set address or token here — TFE manages them.

  auth_login_jwt {
    # Mount path of the JWT auth method in Vault
    mount = var.vault_jwt_auth_path    # default: "jwt"

    # The role granted to this workspace's workload identity JWT.
    # Must match the role created in Vault (see setup notes above).
    role = var.vault_jwt_role          # e.g. "tfe-ibm-demo"

    # The JWT itself is injected by TFE as the env var VAULT_TOKEN_FILE
    # or TFC_VAULT_ENCODED_ID_TOKEN — the provider reads it automatically.
    # No explicit jwt field is needed here.
  }
}

# ── Read IBM API key + SSH public key from Vault KV ───────────────
# Runs after the vault provider has authenticated via JWT above.
data "vault_kv_secret_v2" "ibm_credentials" {
  mount = var.vault_mount_path   # e.g. "kv/ent-demo"
  name  = var.vault_secret_path  # e.g. "ssh/keypair"
}

# ── Extract secrets into locals ───────────────────────────────────
locals {
  ibm_api_key    = data.vault_kv_secret_v2.ibm_credentials.data["ibm_api_key"]
  ssh_public_key = data.vault_kv_secret_v2.ibm_credentials.data["public_key"]
}

# ── IBM Cloud provider — API key sourced from Vault KV ────────────
provider "ibm" {
  region           = var.ibm_region
  ibmcloud_api_key = local.ibm_api_key
}
