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
#   Namespace : admin
#   Mount     : kv
#   Secret    : IBM_cloud     (kv/IBM_cloud)
#   Keys      : public_key    ← SSH public key (already written)
#               ibm_api_key   ← IBM Cloud API key (add before apply)
#
# ── TFC workspace env vars (set once in TFC UI / API) ───────────
#   TFC_VAULT_PROVIDER_AUTH   = true
#   TFC_DEFAULT_VAULT_ADDR    = https://vault-cluster-public-vault-564045ad.ea599dfb.z1.hashicorp.cloud:8200
#   TFC_VAULT_NAMESPACE       = admin
#   TFC_VAULT_PLAN_ROLE       = tfc-role
#   TFC_VAULT_APPLY_ROLE      = tfc-role
#
# ── Add IBM API key to Vault before first apply ──────────────────
#   vault kv patch -namespace=admin -mount=kv IBM_cloud \
#     ibm_api_key="<your-ibm-cloud-api-key>"
# ---------------------------------------------------------------

# ── IBM Cloud General ────────────────────────────────────────────
# Target: eu-de (Frankfurt) · zone eu-de-2
# New VPC and subnet will be created automatically (no existing ones)
ibm_region  = "eu-de"
ibm_zone    = "eu-de-2"
environment = "demo"
project     = "ent-demo"

# ── Networking ───────────────────────────────────────────────────
# Empty strings → Terraform creates a new VPC + subnet in eu-de-2
# subnet_address_count: IBM Cloud auto-carves a /24 (256 IPs) from the
# zone's default address prefix — no CIDR collision possible.
existing_vpc_name    = ""
existing_subnet_name = ""
subnet_address_count = 256

# ── Security / SSH ────────────────────────────────────────────────
ssh_allowed_cidr = "10.0.0.0/8"

# ── Load Balancer / Web App ───────────────────────────────────────
app_port          = 80
health_check_path = "/"

# ── VSI ──────────────────────────────────────────────────────────
vsi_count   = 2
vsi_profile = "bxf-2x8"                      # Flex | 2 vCPU / 8 GB RAM
image_name  = "ibm-centos-stream-9-amd64-17"

# ── HCP Vault Cluster – TFC Dynamic Credentials ──────────────────
# These variables are managed in HCP Terraform workspace variables UI.
# Do NOT set them here to avoid conflicts.
#
# Set the following as Terraform Variables in TFC UI:
#   vault_address     = https://vault-cluster-public-vault-564045ad.ea599dfb.z1.hashicorp.cloud:8200
#   vault_namespace   = admin
#   vault_mount_path  = kv
#   vault_secret_path = IBM_cloud
#
# Set the following as Environment Variables in TFC UI:
#   TFC_VAULT_PROVIDER_AUTH   = true
#   TFC_DEFAULT_VAULT_ADDR    = https://vault-cluster-public-vault-564045ad.ea599dfb.z1.hashicorp.cloud:8200
#   TFC_VAULT_NAMESPACE       = admin
#   TFC_VAULT_PLAN_ROLE       = tfc-role
#   TFC_VAULT_APPLY_ROLE      = tfc-role
