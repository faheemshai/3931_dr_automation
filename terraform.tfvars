# ---------------------------------------------------------------
# terraform.tfvars  –  IBM Cloud DEMO configuration
#
# ── Credential model ────────────────────────────────────────────
# ALL secrets (IBM API key + SSH public key) come from Vault KV.
# Vault itself is authenticated via TFE Dynamic Credentials (JWT).
#
# No static tokens. No API keys. Nothing sensitive lives here.
#
# ── TFE workspace env vars (set once in TFE UI / API) ───────────
#   TFC_VAULT_PROVIDER_AUTH = true
#   TFC_VAULT_ADDR          = https://vault.example.com:8200
#   TFC_VAULT_NAMESPACE     = admin/ent-demo          (Enterprise)
#   TFC_VAULT_RUN_ROLE      = tfe-ibm-demo
#
# ── Load secrets into Vault (one-time, by operator) ─────────────
#   vault kv put kv/ent-demo/ssh/keypair \
#     public_key="$(cat ~/.ssh/id_rsa.pub)" \
#     ibm_api_key="<your-ibm-cloud-api-key>"
# ---------------------------------------------------------------

# ── IBM Cloud General ────────────────────────────────────────────
ibm_region  = "eu-de"
ibm_zone    = "eu-de-2"
environment = "prod"
project     = "ent-demo"

# ── Networking ───────────────────────────────────────────────────
subnet_cidr = "10.240.2.0/24"

# ── Security / SSH ────────────────────────────────────────────────
ssh_allowed_cidr = "10.0.0.0/8"

# ── Load Balancer / Web App ───────────────────────────────────────
app_port          = 80
health_check_path = "/"

# ── VSI ──────────────────────────────────────────────────────────
vsi_count   = 2
vsi_profile = "bx2-2x8"                      # Flex | 2 vCPU / 8 GB RAM
image_name  = "ibm-centos-stream-9-amd64-17"

# ── Vault Enterprise – JWT Dynamic Credentials ───────────────────
# vault_address, vault_token and vault_namespace are injected by TFE.
# Only the JWT auth mount and role name are set here.
vault_jwt_auth_path = "jwt"           # mount path of jwt auth method in Vault
vault_jwt_role      = "tfe-ibm-demo"  # Vault JWT role for this workspace
vault_mount_path    = "kv/ent-demo"   # KV v2 mount
vault_secret_path   = "ssh/keypair"   # secret holding public_key + ibm_api_key
