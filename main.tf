# ---------------------------------------------------------------
# main.tf  –  LAB-3931: Dual-Region DR Infrastructure
#
# PRIMARY  : us-south (Dallas)   — always running
# DR       : eu-de   (Frankfurt) — activated on failover
#
# Architecture: Floating IP per VSI — NO load balancer.
# Each VSI is directly reachable via its own public Floating IP.
#
# Enterprise showcase:
#   • IBM API key sourced from Vault KV — NEVER in code or state
#   • SSH key sourced from Vault KV — NEVER in code or state
#   • Golden image from HCP Packer — consumed by image ID
#   • Floating IPs for direct public VSI access
#   • DR region flagged with role=dr tags for failover targeting
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
  region              = var.ibm_region_primary   # us-south
  version_fingerprint = "fp-20260902165139"
}

data "hcp_packer_artifact" "golden_dr" {
  bucket_name         = "rhel92-golden"
  platform            = "ibmcloud"
  region              = var.ibm_region_dr         # eu-de
  version_fingerprint = "fp-20260902165139"
}

locals {
  # Manual override in terraform.tfvars takes precedence over HCP Packer lookup
  image_id_primary = var.golden_image_id_us_south != "" ? var.golden_image_id_us_south : data.hcp_packer_artifact.golden_primary.external_identifier
  image_id_dr      = var.golden_image_id_eu_de != "" ? var.golden_image_id_eu_de : data.hcp_packer_artifact.golden_dr.external_identifier
}

# ═══════════════════════════════════════════════════════════════
# PRIMARY REGION — us-south
# ═══════════════════════════════════════════════════════════════

module "networking_primary" {
  source = "./modules/vpc"
  providers = {
    ibm = ibm.primary
  }

  project               = var.project
  environment           = var.environment
  ibm_resource_group_id = var.ibm_resource_group_id
  ibm_region            = var.ibm_region_primary
  ibm_zone              = var.ibm_zone_primary
  subnet_address_count  = var.subnet_address_count

  existing_vpc_id      = var.existing_vpc_id_primary
  existing_subnet_id   = var.existing_subnet_id_primary
  existing_vpc_name    = var.existing_vpc_name_primary
  existing_subnet_name = var.existing_subnet_name_primary

  ssh_public_key = local.ssh_public_key
}

module "security_groups_primary" {
  source = "./modules/security_groups"
  providers = {
    ibm = ibm.primary
  }

  project               = var.project
  environment           = var.environment
  ibm_resource_group_id = var.ibm_resource_group_id
  vpc_id                = module.networking_primary.vpc_id
  ssh_allowed_cidr      = var.ssh_allowed_cidr
  app_port              = var.app_port
}

module "vsi_primary" {
  source = "./modules/vsi"
  providers = {
    ibm = ibm.primary
  }

  project               = var.project
  environment           = var.environment
  ibm_resource_group_id = var.ibm_resource_group_id
  ibm_region            = var.ibm_region_primary
  ibm_zone              = var.ibm_zone_primary
  vsi_count             = var.vsi_count
  vsi_profile           = var.vsi_profile
  image_id              = local.image_id_primary
  vpc_id                = module.networking_primary.vpc_id
  subnet_id             = module.networking_primary.subnet_id
  ssh_key_id            = module.networking_primary.ssh_key_id
  vsi_sg_id             = module.security_groups_primary.vsi_sg_id
  app_port              = var.app_port
  dr_role               = "primary"
  dr_pair               = "us-south-eu-de"
}

# ═══════════════════════════════════════════════════════════════
# DR REGION — eu-de  (deployed standby, activated on failover)
# ═══════════════════════════════════════════════════════════════

module "networking_dr" {
  count  = var.DR_infra ? 1 : 0
  source = "./modules/vpc"
  providers = {
    ibm = ibm.dr
  }

  project               = var.project
  environment           = "${var.environment}-dr"
  ibm_resource_group_id = var.ibm_resource_group_id
  ibm_region            = var.ibm_region_dr
  ibm_zone              = var.ibm_zone_dr
  subnet_address_count  = var.subnet_address_count

  existing_vpc_id      = var.existing_vpc_id_dr
  existing_subnet_id   = var.existing_subnet_id_dr
  existing_vpc_name    = var.existing_vpc_name_dr
  existing_subnet_name = var.existing_subnet_name_dr

  ssh_public_key = local.ssh_public_key
}

module "security_groups_dr" {
  count  = var.DR_infra ? 1 : 0
  source = "./modules/security_groups"
  providers = {
    ibm = ibm.dr
  }

  project               = var.project
  environment           = "${var.environment}-dr"
  ibm_resource_group_id = var.ibm_resource_group_id
  vpc_id                = module.networking_dr[0].vpc_id
  ssh_allowed_cidr      = var.ssh_allowed_cidr
  app_port              = var.app_port
}

module "vsi_dr" {
  count  = var.DR_infra ? 1 : 0
  source = "./modules/vsi"
  providers = {
    ibm = ibm.dr
  }

  project               = var.project
  environment           = "${var.environment}-dr"
  ibm_resource_group_id = var.ibm_resource_group_id
  ibm_region            = var.ibm_region_dr
  ibm_zone              = var.ibm_zone_dr
  vsi_count             = var.vsi_count
  vsi_profile           = var.vsi_profile
  image_id              = local.image_id_dr
  vpc_id                = module.networking_dr[0].vpc_id
  subnet_id             = module.networking_dr[0].subnet_id
  ssh_key_id            = module.networking_dr[0].ssh_key_id
  vsi_sg_id             = module.security_groups_dr[0].vsi_sg_id
  app_port              = var.app_port
  dr_role               = "dr"
  dr_pair               = "us-south-eu-de"
}
