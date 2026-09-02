# ---------------------------------------------------------------
# modules/vpc/main.tf
#
# Lookup priority (highest → lowest):
#   1. existing_vpc_id / existing_subnet_id  — direct ID lookup (fastest)
#   2. existing_vpc_name / existing_subnet_name — name-based lookup
#   3. create new VPC / subnet                 — when all above are empty
#
# The outputs always expose a single vpc_id and subnet_id regardless
# of which path was taken, so callers never need to know.
#
# Dedicated lab account IDs:
#   us-south  VPC    : r006-76dee245-0417-4682-951e-2b1d149a7639
#   us-south  subnet : 0717-c20d5d2d-6216-4b99-88d7-8b441ef20a9e
#   eu-de     VPC    : r010-75fc4ba7-8a56-4a42-baaa-b6691a7f24ac
#   eu-de     subnet : 02b7-df5e6a98-fa9c-4e87-b67c-057d360b62ba
# ---------------------------------------------------------------

locals {
  name_prefix = "${var.project}-${var.environment}"

  # Lookup mode flags — ID takes priority over name
  use_vpc_by_id     = var.existing_vpc_id != ""
  use_vpc_by_name   = !local.use_vpc_by_id && var.existing_vpc_name != ""
  create_vpc        = !local.use_vpc_by_id && !local.use_vpc_by_name

  use_subnet_by_id   = var.existing_subnet_id != ""
  use_subnet_by_name = !local.use_subnet_by_id && var.existing_subnet_name != ""
  create_subnet      = !local.use_subnet_by_id && !local.use_subnet_by_name
}

# ── VPC: look up by ID (preferred path) ──────────────────────────
data "ibm_is_vpc" "by_id" {
  count      = local.use_vpc_by_id ? 1 : 0
  identifier = var.existing_vpc_id
}

# ── VPC: look up by name (fallback) ──────────────────────────────
data "ibm_is_vpc" "by_name" {
  count = local.use_vpc_by_name ? 1 : 0
  name  = var.existing_vpc_name
}

# ── VPC: create new (only when no ID or name given) ───────────────
resource "ibm_is_vpc" "new" {
  count = local.create_vpc ? 1 : 0
  name  = "${local.name_prefix}-vpc"

  tags = ["project:${var.project}", "env:${var.environment}", "managed-by:terraform"]
}

# ── Resolved VPC ID ───────────────────────────────────────────────
locals {
  vpc_id = (
    local.use_vpc_by_id   ? data.ibm_is_vpc.by_id[0].id   :
    local.use_vpc_by_name ? data.ibm_is_vpc.by_name[0].id :
    ibm_is_vpc.new[0].id
  )
}

# ── Subnet: look up by ID (preferred path) ───────────────────────
data "ibm_is_subnet" "by_id" {
  count      = local.use_subnet_by_id ? 1 : 0
  identifier = var.existing_subnet_id
}

# ── Subnet: look up by name (fallback) ───────────────────────────
data "ibm_is_subnet" "by_name" {
  count = local.use_subnet_by_name ? 1 : 0
  name  = var.existing_subnet_name
}

# ── Subnet: create new (only when no ID or name given) ────────────
# IBM Cloud requires the subnet CIDR to be a strict subset of one of
# the VPC's zone address prefixes. Rather than hardcoding a CIDR that
# must manually match IBM's auto-created prefix, we use
# total_ipv4_address_count — IBM Cloud picks a valid CIDR automatically
# from the zone's default address prefix.
resource "ibm_is_subnet" "new" {
  count                    = local.create_subnet ? 1 : 0
  name                     = "${local.name_prefix}-subnet-${var.ibm_zone}"
  vpc                      = local.vpc_id
  zone                     = var.ibm_zone
  total_ipv4_address_count = var.subnet_address_count

  tags = ["project:${var.project}", "env:${var.environment}", "managed-by:terraform"]
}

# ── Resolved Subnet ID ────────────────────────────────────────────
locals {
  subnet_id = (
    local.use_subnet_by_id   ? data.ibm_is_subnet.by_id[0].id   :
    local.use_subnet_by_name ? data.ibm_is_subnet.by_name[0].id :
    ibm_is_subnet.new[0].id
  )
}

# ── SSH Key (public key loaded from Vault) ────────────────────────
resource "ibm_is_ssh_key" "vault_key" {
  name       = "${local.name_prefix}-vault-key"
  public_key = var.ssh_public_key

  tags = ["project:${var.project}", "env:${var.environment}", "source:vault"]
}
