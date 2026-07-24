# ---------------------------------------------------------------
# main.tf  –  Root module
# Wires VPC → Security Groups → ALB → EC2 → Vault integration
# ---------------------------------------------------------------

# ── 1. Vault Integration (read/write secrets) ─────────────────────
module "vault_integration" {
  source = "./modules/vault_integration"

  project     = var.project
  environment = var.environment
  kv_mount    = var.vault_mount_path
  secret_path = var.vault_secret_path
}

# ── 2. VPC ────────────────────────────────────────────────────────
module "vpc" {
  source = "./modules/vpc"

  project              = var.project
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
}

# ── 3. Security Groups ────────────────────────────────────────────
module "security_groups" {
  source = "./modules/security_groups"

  project      = var.project
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
  bastion_cidr = var.bastion_cidr
}

# ── 4. Application Load Balancer ─────────────────────────────────
module "alb" {
  source = "./modules/alb"

  project           = var.project
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  alb_sg_id         = module.security_groups.alb_sg_id
  health_check_path = var.health_check_path
  app_port          = var.app_port
}

# ── 5. EC2 / ASG – credentials flow from Vault ───────────────────
module "ec2" {
  source = "./modules/ec2"

  project            = var.project
  environment        = var.environment
  ami_id             = var.ami_id
  instance_type      = var.instance_type
  private_subnet_ids = module.vpc.private_subnet_ids
  app_sg_id          = module.security_groups.app_sg_id
  target_group_arn   = module.alb.target_group_arn
  desired_capacity   = var.desired_capacity
  min_size           = var.min_size
  max_size           = var.max_size

  # ── Credentials piped from Vault ─────────────────────────────
  db_username = module.vault_integration.db_username
  db_password = module.vault_integration.db_password
  app_api_key = module.vault_integration.app_api_key
}
