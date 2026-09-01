# ---------------------------------------------------------------
# main.tf  –  LAB-3931: Dual-Region DR Infrastructure
#
# PRIMARY  : us-south (Dallas)   — always running
# DR       : eu-de   (Frankfurt) — activated on failover
#
# Enterprise showcase:
#   • IBM API key sourced from Vault KV — NEVER in code or state
#   • SSH key sourced from Vault KV — NEVER in code or state
#   • Golden image from Packer build — consumed by image ID
#   • DR region flagged with role=dr tags for failover targeting
#   • Identical module calls per region — one source of truth
# ---------------------------------------------------------------

# ── 1. Vault — read IBM credentials (single read, shared) ────────
module "vault_integration" {
  source = "./modules/vault_integration"

  project     = var.project
  environment = var.environment
  kv_mount    = var.vault_mount_path
  secret_path = var.vault_secret_path
}

# ── 2. HCP Packer — read golden image artifacts dynamically ──────
data "hcp_packer_artifact" "golden_primary" {
  bucket_name         = "rhel92-golden"
  platform            = "ibmcloud"
  region              = var.ibm_region_primary
  version_fingerprint = "fp-20260901180747"
}

data "hcp_packer_artifact" "golden_dr" {
  bucket_name         = "rhel92-golden"
  platform            = "ibmcloud"
  region              = var.ibm_region_primary # fallback during Task 1 / Task 2 setup
  version_fingerprint = "fp-20260901180747"
}

locals {
  # Dynamic lookup from HCP Packer with manual override fallback
  image_id_primary = var.golden_image_id_us_south != "" ? var.golden_image_id_us_south : data.hcp_packer_artifact.golden_primary.external_identifier
  image_id_dr      = var.golden_image_id_eu_de != "" ? var.golden_image_id_eu_de : data.hcp_packer_artifact.golden_dr.external_identifier
}

# ═══════════════════════════════════════════════════════════════
# PRIMARY REGION — us-south
# ═══════════════════════════════════════════════════════════════

module "networking_primary" {
  source = "./modules/vpc"

  project              = var.project
  environment          = var.environment
  ibm_region           = var.ibm_region_primary
  ibm_zone             = var.ibm_zone_primary
  subnet_address_count = var.subnet_address_count
  existing_vpc_name    = var.existing_vpc_name_primary
  existing_subnet_name = var.existing_subnet_name_primary
  ssh_public_key       = module.vault_integration.ssh_public_key
}

module "security_groups_primary" {
  source = "./modules/security_groups"

  project          = var.project
  environment      = var.environment
  vpc_id           = module.networking_primary.vpc_id
  ssh_allowed_cidr = var.ssh_allowed_cidr
  app_port         = var.app_port
}

module "alb_primary" {
  source = "./modules/alb"

  project           = var.project
  environment       = var.environment
  ibm_region        = var.ibm_region_primary
  subnet_id         = module.networking_primary.subnet_id
  app_port          = var.app_port
  health_check_path = var.health_check_path
}

module "vsi_primary" {
  source = "./modules/vsi"

  project      = var.project
  environment  = var.environment
  ibm_region   = var.ibm_region_primary
  ibm_zone     = var.ibm_zone_primary
  vsi_count    = var.vsi_count
  vsi_profile  = var.vsi_profile

  # Golden image from Packer — resolved dynamically
  image_id     = local.image_id_primary

  vpc_id       = module.networking_primary.vpc_id
  subnet_id    = module.networking_primary.subnet_id
  ssh_key_id   = module.networking_primary.ssh_key_id
  lb_sg_id     = module.security_groups_primary.lb_sg_id
  vsi_sg_id    = module.security_groups_primary.vsi_sg_id
  lb_id        = module.alb_primary.lb_id
  lb_pool_id   = module.alb_primary.pool_id
  app_port     = var.app_port

  # DR metadata — used by failover scripts to target the right VSIs
  dr_role      = "primary"
  dr_pair      = "us-south-eu-de"
}

# ═══════════════════════════════════════════════════════════════
# DR REGION — eu-de  (deployed standby, activated on failover)
# ═══════════════════════════════════════════════════════════════

module "networking_dr" {
  source = "./modules/vpc"

  project              = var.project
  environment          = "${var.environment}-dr"
  ibm_region           = var.ibm_region_dr
  ibm_zone             = var.ibm_zone_dr
  subnet_address_count = var.subnet_address_count
  existing_vpc_name    = var.existing_vpc_name_dr
  existing_subnet_name = var.existing_subnet_name_dr
  ssh_public_key       = module.vault_integration.ssh_public_key
}

module "security_groups_dr" {
  source = "./modules/security_groups"

  project          = var.project
  environment      = "${var.environment}-dr"
  vpc_id           = module.networking_dr.vpc_id
  ssh_allowed_cidr = var.ssh_allowed_cidr
  app_port         = var.app_port
}

module "alb_dr" {
  source = "./modules/alb"

  project           = var.project
  environment       = "${var.environment}-dr"
  ibm_region        = var.ibm_region_dr
  subnet_id         = module.networking_dr.subnet_id
  app_port          = var.app_port
  health_check_path = var.health_check_path
}

module "vsi_dr" {
  source      = "./modules/vsi"

  project      = var.project
  environment  = "${var.environment}-dr"
  ibm_region   = var.ibm_region_dr
  ibm_zone     = var.ibm_zone_dr
  vsi_count    = var.enable_dr ? var.vsi_count : 0
  vsi_profile  = var.vsi_profile

  # Same golden image family — eu-de variant — resolved dynamically, fallback to primary when disabled
  image_id     = var.enable_dr ? local.image_id_dr : local.image_id_primary

  vpc_id       = module.networking_dr.vpc_id
  subnet_id    = module.networking_dr.subnet_id
  ssh_key_id   = module.networking_dr.ssh_key_id
  lb_sg_id     = module.security_groups_dr.lb_sg_id
  vsi_sg_id    = module.security_groups_dr.vsi_sg_id
  lb_id        = module.alb_dr.lb_id
  lb_pool_id   = module.alb_dr.pool_id
  app_port     = var.app_port

  dr_role      = "dr"
  dr_pair      = "us-south-eu-de"
}
