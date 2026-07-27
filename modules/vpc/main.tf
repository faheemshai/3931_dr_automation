# ---------------------------------------------------------------
# modules/vpc/main.tf
#
# Strategy: use existing VPC / subnet when names are provided,
# create new ones only when the name variables are left empty.
#
#   existing_vpc_name    = ""        → creates <project>-<env>-vpc
#   existing_vpc_name    = "my-vpc"  → looks up VPC named "my-vpc"
#
#   existing_subnet_name = ""              → creates subnet with subnet_cidr
#   existing_subnet_name = "my-subnet"     → looks up that subnet
#
# The outputs always expose a single vpc_id and subnet_id regardless
# of whether the resource was found or created.
# ---------------------------------------------------------------

locals {
  name_prefix = "${var.project}-${var.environment}"

  # true = a name was supplied → look up existing resource
  use_existing_vpc    = var.existing_vpc_name != ""
  use_existing_subnet = var.existing_subnet_name != ""
}

# ── VPC: look up existing ─────────────────────────────────────────
data "ibm_is_vpc" "existing" {
  count = local.use_existing_vpc ? 1 : 0
  name  = var.existing_vpc_name
}

# ── VPC: create new (only when no existing name given) ────────────
resource "ibm_is_vpc" "new" {
  count = local.use_existing_vpc ? 0 : 1
  name  = "${local.name_prefix}-vpc"

  tags = ["project:${var.project}", "env:${var.environment}", "managed-by:terraform"]
}

# ── Resolved VPC ID (whichever path was taken) ────────────────────
locals {
  vpc_id = local.use_existing_vpc ? data.ibm_is_vpc.existing[0].id : ibm_is_vpc.new[0].id
}

# ── Subnet: look up existing ──────────────────────────────────────
data "ibm_is_subnet" "existing" {
  count = local.use_existing_subnet ? 1 : 0
  name  = var.existing_subnet_name
}

# ── Subnet: create new (only when no existing name given) ─────────
# IBM Cloud requires the subnet CIDR to be a strict subset of one of
# the VPC's zone address prefixes. Rather than hardcoding a CIDR that
# must manually match IBM's auto-created prefix, we use
# total_ipv4_address_count — IBM Cloud picks a valid CIDR automatically
# from the zone's default address prefix (e.g. 10.240.64.0/18 for eu-de-2).
resource "ibm_is_subnet" "new" {
  count                    = local.use_existing_subnet ? 0 : 1
  name                     = "${local.name_prefix}-subnet-${var.ibm_zone}"
  vpc                      = local.vpc_id
  zone                     = var.ibm_zone
  total_ipv4_address_count = var.subnet_address_count

  tags = ["project:${var.project}", "env:${var.environment}", "managed-by:terraform"]
}

# ── Resolved Subnet ID (whichever path was taken) ─────────────────
locals {
  subnet_id = local.use_existing_subnet ? data.ibm_is_subnet.existing[0].id : ibm_is_subnet.new[0].id
}

# ── SSH Key (public key loaded from Vault Enterprise) ────────────
resource "ibm_is_ssh_key" "vault_key" {
  name       = "${local.name_prefix}-vault-key"
  public_key = var.ssh_public_key

  tags = ["project:${var.project}", "env:${var.environment}", "source:vault"]
}
