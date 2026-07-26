# ---------------------------------------------------------------
# modules/vpc/main.tf
# Uses the default VPC in the target region.
# Creates one subnet in eu-de-2 and registers the Vault SSH public
# key as an IBM Cloud SSH key for VSI provisioning.
# ---------------------------------------------------------------

locals {
  name_prefix = "${var.project}-${var.environment}"
}

# ── Look up the default VPC ───────────────────────────────────────
data "ibm_is_vpc" "default" {
  name = "default"
}

# ── Subnet in eu-de-2 ────────────────────────────────────────────
resource "ibm_is_subnet" "app" {
  name            = "${local.name_prefix}-subnet-${var.ibm_zone}"
  vpc             = data.ibm_is_vpc.default.id
  zone            = var.ibm_zone
  ipv4_cidr_block = var.subnet_cidr

  tags = ["project:${var.project}", "env:${var.environment}", "managed-by:terraform"]
}

# ── SSH Key (public key loaded from Vault Enterprise) ────────────
resource "ibm_is_ssh_key" "vault_key" {
  name       = "${local.name_prefix}-vault-key"
  public_key = var.ssh_public_key

  tags = ["project:${var.project}", "env:${var.environment}", "source:vault"]
}
