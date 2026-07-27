# ---------------------------------------------------------------
# terraform.tfvars  –  IBM Cloud DEMO configuration
#
# ── Credential model ────────────────────────────────────────────
# ALL secrets (IBM API key + SSH public key) come from Vault KV.
# Vault itself is authenticated via TFE Dynamic Credentials (JWT).
#
# No static tokens. No API keys. Nothing sensitive lives here.
#
# ── Vault location ───────────────────────────────────────────────
#   Namespace : eelab/Catalyst
#   Mount     : kv
#   Secret    : terraform     (kv/terraform)
#   Keys      : public_key    ← SSH public key (already written)
#               ibm_api_key   ← IBM Cloud API key (add before apply)
#
# ── TFE workspace env vars (set once in TFE UI / API) ───────────
#   TFC_VAULT_PROVIDER_AUTH = true
#   TFC_VAULT_ADDR          = https://vault.example.com:8200
#   TFC_VAULT_NAMESPACE     = eelab/Catalyst
#   TFC_VAULT_RUN_ROLE      = tfe-ibm-demo
#
# ── Add IBM API key to Vault before first apply ──────────────────
#   vault kv patch -namespace=eelab/Catalyst kv/terraform \
#     ibm_api_key="<your-ibm-cloud-api-key>"
# ---------------------------------------------------------------

# ── IBM Cloud General ────────────────────────────────────────────
ibm_region  = "eu-de"
ibm_zone    = "eu-de-2"
environment = "prod"
project     = "ent-demo"

# ── Networking ───────────────────────────────────────────────────
# Set the exact names from IBM Cloud console (VPC → VPCs / Subnets).
# IBM Cloud does not auto-create a VPC named "default" — use the real name.
# Leave either value as "" to have Terraform create a new resource.
existing_vpc_name    = "vpc-eelab"      # ← replace with name from IBM Cloud console
existing_subnet_name = "sn-20260511-2"   # ← replace with name from IBM Cloud console
# subnet_cidr          = "10.240.2.0/24"     # only used if existing_subnet_name = ""

# ── Security / SSH ────────────────────────────────────────────────
ssh_allowed_cidr = "10.0.0.0/8"

# ── Load Balancer / Web App ───────────────────────────────────────
app_port          = 80
health_check_path = "/"

# ── VSI ──────────────────────────────────────────────────────────
vsi_count   = 2
vsi_profile = "bx2-2x8"                      # Flex | 2 vCPU / 8 GB RAM
image_name  = "ibm-centos-stream-9-amd64-17"

# ── Vault Enterprise – TFE Dynamic Credentials ───────────────────
# Values match the credential set configured in TFE (screenshot):
#   TFC_DEFAULT_VAULT_ADDR  = https://enterprise-vault.automation-...
#   TFC_VAULT_NAMESPACE     = eelab/Catalyst
#   TFC_VAULT_PLAN_ROLE     = tfc-role
#   TFC_VAULT_PROVIDER_AUTH = true
vault_address     = "https://enterprise-vault.automation-18fdda76ef7730b16bdb4cb5e693c1eb-0000.us-south.containers.appdomain.cloud"
vault_namespace   = "eelab/Catalyst"
vault_mount_path  = "kv"
vault_secret_path = "terraform"   # kv/terraform holds public_key + ibm_api_key
