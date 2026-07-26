# ---------------------------------------------------------------
# Providers
# ---------------------------------------------------------------

provider "ibm" {
  region = var.ibm_region

  # Credentials — set via environment variables (recommended):
  #   export IC_API_KEY="<your IBM Cloud API key>"
  # Or supply directly:
  #   ibmcloud_api_key = var.ibmcloud_api_key
}

provider "vault" {
  address   = var.vault_address
  token     = var.vault_token
  namespace = var.vault_namespace != "" ? var.vault_namespace : null
}
