# ---------------------------------------------------------------
# providers.tf  –  LAB-3931 DR Automation
#
# Enterprise showcase: ZERO static credentials anywhere.
#
# ── How secrets flow ────────────────────────────────────────────
#   HCP Terraform workspace
#     └─ TFC_VAULT_PROVIDER_AUTH=true
#         └─ mints workload-identity JWT
#             └─ Vault JWT auth → scoped token (VAULT_TOKEN)
#                 └─ vault provider reads kv/IBM_cloud
#                     └─ ibm_api_key → IBM provider (both regions)
#
# ── Required TFE workspace env vars (set once in TFE UI) ────────
#   TFC_VAULT_PROVIDER_AUTH  = true
#   TFC_DEFAULT_VAULT_ADDR   = https://vault-cluster-3931-public-vault-0d5d4e35.e84a65be.z1.hashicorp.cloud:8200
#   TFC_VAULT_NAMESPACE      = admin
#   TFC_VAULT_PLAN_ROLE      = tfc-role
#   TFC_VAULT_APPLY_ROLE     = tfc-role
#
# ── Why the address is hardcoded here (not from var.vault_address) ──
#   TFC dynamic credentials inject the VAULT_TOKEN via TFC_DEFAULT_VAULT_ADDR,
#   but the vault provider's 'address' argument controls the DNS target for
#   all subsequent API calls. Using a variable here caused the provider to
#   briefly connect to the wrong cluster before tfvars was loaded.
#   Hardcoding the address in the provider block eliminates that race.
# ---------------------------------------------------------------

# ── Vault provider (token injected by TFE dynamic creds) ─────────
provider "vault" {
  # Address hardcoded — must match TFC_DEFAULT_VAULT_ADDR exactly
  address   = "https://vault-cluster-3931-public-vault-0d5d4e35.e84a65be.z1.hashicorp.cloud:8200"
  namespace = "admin"
}

# ── IBM API key from Vault ────────────────────────────────────────
data "vault_kv_secret_v2" "ibm_credentials" {
  mount = var.vault_mount_path
  name  = var.vault_secret_path
}

locals {
  ibm_api_key    = data.vault_kv_secret_v2.ibm_credentials.data["ibm_api_key"]
  ssh_public_key = data.vault_kv_secret_v2.ibm_credentials.data["public_key"]
}

# ── IBM Cloud provider — PRIMARY us-south ────────────────────────
# Same API key, different region alias — Terraform picks the right
# provider per module using provider = ibm.primary / ibm.dr.
provider "ibm" {
  alias            = "primary"
  region           = var.ibm_region_primary
  ibmcloud_api_key = local.ibm_api_key
}

# ── IBM Cloud provider — DR eu-de ────────────────────────────────
provider "ibm" {
  alias            = "dr"
  region           = var.ibm_region_dr
  ibmcloud_api_key = local.ibm_api_key
}

# ── Default IBM provider (for any resources not region-specific) ──
provider "ibm" {
  region           = var.ibm_region_primary
  ibmcloud_api_key = local.ibm_api_key
}

# ── HCP credentials from Vault ────────────────────────────────────
data "vault_kv_secret_v2" "hcp_credentials" {
  mount = var.vault_mount_path
  name  = "Packer"
}

# ── HCP Provider (HCP Packer Integration) ────────────────────────
provider "hcp" {
  client_id     = data.vault_kv_secret_v2.hcp_credentials.data["HCP_CLIENT_ID"]
  client_secret = data.vault_kv_secret_v2.hcp_credentials.data["HCP_CLIENT_SECRET"]
}
