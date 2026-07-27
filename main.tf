# ---------------------------------------------------------------
# main.tf  –  Root module
# Wires: Vault SSH key → networking → security groups → LB → VSIs
# Target: IBM Cloud eu-de-2 | Default VPC | 2 × bx2-2x8 VSIs
# ---------------------------------------------------------------

# ── 1. Vault Integration (SSH key pair from Vault Enterprise) ─────
module "vault_integration" {
  source = "./modules/vault_integration"

  project     = var.project
  environment = var.environment
  kv_mount    = var.vault_mount_path
  secret_path = var.vault_secret_path
}

# ── 2. Networking ────────────────────────────────────────────────
# Set existing_vpc_name / existing_subnet_name in terraform.tfvars
# to reuse existing IBM Cloud resources.
# Leave empty ("") to create new ones automatically.
module "networking" {
  source = "./modules/vpc"

  project              = var.project
  environment          = var.environment
  ibm_region           = var.ibm_region
  ibm_zone             = var.ibm_zone
  subnet_cidr          = var.subnet_cidr
  existing_vpc_name    = var.existing_vpc_name
  existing_subnet_name = var.existing_subnet_name

  # IBM Cloud SSH key – public key retrieved from Vault
  ssh_public_key = module.vault_integration.ssh_public_key
}

# ── 3. Security Groups ────────────────────────────────────────────
module "security_groups" {
  source = "./modules/security_groups"

  project          = var.project
  environment      = var.environment
  vpc_id           = module.networking.vpc_id
  ssh_allowed_cidr = var.ssh_allowed_cidr
  app_port         = var.app_port
}

# ── 4. Application Load Balancer ─────────────────────────────────
module "alb" {
  source = "./modules/alb"

  project           = var.project
  environment       = var.environment
  ibm_region        = var.ibm_region
  subnet_id         = module.networking.subnet_id
  app_port          = var.app_port
  health_check_path = var.health_check_path
}

# ── 5. VSIs – SSH key & target pool wired from Vault + LB ────────
module "vsi" {
  source = "./modules/vsi"

  project        = var.project
  environment    = var.environment
  ibm_zone       = var.ibm_zone
  vsi_count      = var.vsi_count
  vsi_profile    = var.vsi_profile
  image_name     = var.image_name
  vpc_id         = module.networking.vpc_id
  subnet_id      = module.networking.subnet_id
  ssh_key_id     = module.networking.ssh_key_id
  lb_sg_id       = module.security_groups.lb_sg_id
  vsi_sg_id      = module.security_groups.vsi_sg_id
  lb_id          = module.alb.lb_id
  lb_pool_id     = module.alb.pool_id
  app_port       = var.app_port
}
