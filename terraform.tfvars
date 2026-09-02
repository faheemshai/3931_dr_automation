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

# ── IBM Cloud resource group ──────────────────────────────────────
# Dedicated lab account resource group ID
ibm_resource_group_id = "90733208e12b46eda9c4fbc130b8e426"

# ── PRIMARY — us-south ───────────────────────────────────────────
ibm_region_primary  = "us-south"
ibm_zone_primary    = "us-south-1"
# ID-based lookup — takes precedence over name-based lookup when set
existing_vpc_id_primary    = "r006-76dee245-0417-4682-951e-2b1d149a7639"
existing_subnet_id_primary = "0717-c20d5d2d-6216-4b99-88d7-8b441ef20a9e"
# Name-based fallback (leave as "" when using ID-based above)
existing_vpc_name_primary    = ""
existing_subnet_name_primary = ""

# ── DR — eu-de ───────────────────────────────────────────────────
ibm_region_dr = "eu-de"
ibm_zone_dr   = "eu-de-2"
# ID-based lookup for eu-de (pre-provisioned dedicated lab VPC)
existing_vpc_id_dr    = "r010-75fc4ba7-8a56-4a42-baaa-b6691a7f24ac"
existing_subnet_id_dr = "02b7-df5e6a98-fa9c-4e87-b67c-057d360b62ba"
# Name-based fallback (leave as "" when using ID-based above)
existing_vpc_name_dr    = ""
existing_subnet_name_dr = ""

# ── Packer golden images ──────────────────────────────────────────
# If left as empty "", they resolve dynamically from HCP Packer.
# Manual override (our newly built golden image ID):
# Updated from packer-manifest.json after build on 2026-09-02 (run: 7dee771e)
golden_image_id_us_south = "r006-fe8ccdb8-d39a-4c75-91d1-2f763b31f360"
golden_image_id_eu_de    = "r010-13c7e12e-1df5-4ca2-ba0b-478fa6c6ac6c"

# ── VSI ──────────────────────────────────────────────────────────
vsi_count   = 1
vsi_profile = "cx2-2x4"

# ── Networking ───────────────────────────────────────────────────
subnet_address_count = 256
# Dedicated lab account — open SSH from anywhere (restrict in production)
ssh_allowed_cidr = "0.0.0.0/0"

# ── App ──────────────────────────────────────────────────────────
app_port          = 80
health_check_path = "/"

# ── Vault ────────────────────────────────────────────────────────
vault_address     = "https://vault-cluster-public-vault-564045ad.ea599dfb.z1.hashicorp.cloud:8200"
vault_namespace   = "admin"
vault_mount_path  = "kv"
vault_secret_path = "IBM_cloud"
