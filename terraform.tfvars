# ---------------------------------------------------------------
# terraform.tfvars  –  LAB-3931 DR Automation
#
# ── Credential model ────────────────────────────────────────────
# ALL secrets come from Vault KV (kv/IBM_cloud):
#   ibm_api_key   → IBM Cloud provider auth
#   public_key    → SSH key uploaded to both regions
#
# Vault is authenticated via HCP Terraform Dynamic Credentials.
# Zero static secrets anywhere in this file or Terraform state.
#
# ── Golden images ────────────────────────────────────────────────
# After each Packer build, update golden_image_name_us_south
# from packer/packer-manifest.json → builds[last].artifact_id,
# then: ibmcloud is image <id> --output json | jq -r '.name'
# ---------------------------------------------------------------

project     = "lab3931"
environment = "demo"

# ── PRIMARY — us-south ───────────────────────────────────────────
ibm_region_primary           = "us-south"
ibm_zone_primary             = "us-south-1"
existing_vpc_name_primary    = "vpc-eelab"
existing_subnet_name_primary = "sn-20260511-1"

# ── DR — eu-de ───────────────────────────────────────────────────
ibm_region_dr           = "eu-de"
ibm_zone_dr             = "eu-de-2"
existing_vpc_name_dr    = ""
existing_subnet_name_dr = ""

# ── Packer golden images ──────────────────────────────────────────
# If left as empty "", they resolve dynamically from HCP Packer.
# Manual override (our newly built golden image ID):
golden_image_id_us_south = "r006-77571d18-ba11-4fbc-af9e-0ed9e3312190"
golden_image_id_eu_de    = "r006-77571d18-ba11-4fbc-af9e-0ed9e3312190" # fallback during Task 1

# ── VSI ──────────────────────────────────────────────────────────
vsi_count   = 1
vsi_profile = "cx2-2x4"

# ── Networking ───────────────────────────────────────────────────
subnet_address_count = 256
ssh_allowed_cidr     = "10.0.0.0/8"

# ── App ──────────────────────────────────────────────────────────
app_port          = 80
health_check_path = "/"

# ── Vault ────────────────────────────────────────────────────────
vault_address     = "https://vault-cluster-public-vault-564045ad.ea599dfb.z1.hashicorp.cloud:8200"
vault_namespace   = "admin"
vault_mount_path  = "kv"
vault_secret_path = "IBM_cloud"
