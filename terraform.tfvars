# ---------------------------------------------------------------
# terraform.tfvars  –  IBM Cloud DEMO configuration
#
# SSH key is stored in Vault Enterprise under kv/ent-demo/ssh/keypair
# and is read at plan/apply time by the vault_integration module.
#
# ⚠️  Set secrets via env vars — never commit them:
#   export IC_API_KEY="<your IBM Cloud API key>"
#   export TF_VAR_vault_token="<your Vault token>"
# ---------------------------------------------------------------

# ── IBM Cloud General ────────────────────────────────────────────
ibm_region  = "eu-de"
ibm_zone    = "eu-de-2"
environment = "prod"
project     = "ent-demo"

# ── Networking ───────────────────────────────────────────────────
# Subnet created in eu-de-2 inside the default VPC
subnet_cidr = "10.240.2.0/24"

# ── Security / SSH ────────────────────────────────────────────────
# Restrict SSH to your bastion / VPN CIDR before going live
ssh_allowed_cidr = "10.0.0.0/8"

# ── Load Balancer / Web App ───────────────────────────────────────
app_port          = 80
health_check_path = "/"

# ── VSI ──────────────────────────────────────────────────────────
vsi_count   = 2
vsi_profile = "bx2-2x8"                      # Flex | 2 vCPU / 8 GB RAM
image_name  = "ibm-centos-stream-9-amd64-17"

# ── Vault Enterprise ─────────────────────────────────────────────
vault_address     = "http://127.0.0.1:8200"
# vault_token     = "..."   ← Set via: export TF_VAR_vault_token=<token>
vault_namespace   = ""      # Set to your Vault Enterprise namespace (e.g. "admin/ent-demo")
vault_mount_path  = "kv/ent-demo"
vault_secret_path = "ssh/keypair"
