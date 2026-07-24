# ---------------------------------------------------------------
# terraform.tfvars  –  DEMO configuration
#
# ⚠️  Phase A (before Vault migration): dummy credentials live
#    inside modules/vault_integration/main.tf and are written to
#    Vault automatically on first apply.
#
# ⚠️  Phase B (after Vault migration): update real values in Vault
#    using the Vault CLI / UI / API, then re-run `terraform apply`.
#    The EC2 instances are refreshed via Instance Refresh (rolling).
# ---------------------------------------------------------------

# ── General ──────────────────────────────────────────────────────
aws_region  = "us-east-1"
environment = "prod"
project     = "ent-demo"

# ── Networking ───────────────────────────────────────────────────
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
availability_zones   = ["us-east-1a", "us-east-1b"]

# ── Security Groups ───────────────────────────────────────────────
# Restrict SSH to your bastion host / VPN CIDR before going live
bastion_cidr = "10.0.0.0/8"

# ── ALB ──────────────────────────────────────────────────────────
health_check_path = "/health"
app_port          = 8080

# ── EC2 ──────────────────────────────────────────────────────────
instance_type    = "t3.micro"
ami_id           = "ami-0c101f26f147fa7fd"
desired_capacity = 2
min_size         = 1
max_size         = 4

# ── Vault ─────────────────────────────────────────────────────────
vault_address     = "http://127.0.0.1:8200"
# vault_token     = "..."   ← Set via: export TF_VAR_vault_token=<token>
vault_namespace   = ""     # Set to your Vault Enterprise namespace (e.g. "admin/ent-demo")
vault_mount_path  = "kv/ent-demo"
vault_secret_path = "app/credentials"
