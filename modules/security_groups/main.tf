# ---------------------------------------------------------------
# modules/security_groups/main.tf
#
# Single VSI security group — no load balancer in this architecture.
# Traffic reaches VSIs directly via Floating IPs.
#
# Inbound:
#   port 22  — SSH from any IP (controlled by ssh_allowed_cidr)
#   port 80  — HTTP from internet (0.0.0.0/0)
#   port 443 — HTTPS from internet (0.0.0.0/0)
# Outbound:
#   all      — unrestricted (dnf, Vault, IBM API calls)
# ---------------------------------------------------------------

locals {
  name_prefix = "${var.project}-${var.environment}"
}

# ── VSI Security Group ────────────────────────────────────────────
resource "ibm_is_security_group" "vsi" {
  name           = "${local.name_prefix}-vsi-sg"
  vpc            = var.vpc_id
  resource_group = var.ibm_resource_group_id

  tags = ["project:${var.project}", "env:${var.environment}", "managed-by:terraform"]
}

# Allow inbound SSH
resource "ibm_is_security_group_rule" "vsi_inbound_ssh" {
  group     = ibm_is_security_group.vsi.id
  direction = "inbound"
  remote    = var.ssh_allowed_cidr
  protocol  = "tcp"
  port_min  = 22
  port_max  = 22
}

# Allow inbound HTTP from internet — Floating IP access
resource "ibm_is_security_group_rule" "vsi_inbound_http" {
  group     = ibm_is_security_group.vsi.id
  direction = "inbound"
  remote    = "0.0.0.0/0"
  protocol  = "tcp"
  port_min  = 80
  port_max  = 80
}

# Allow inbound HTTPS from internet
resource "ibm_is_security_group_rule" "vsi_inbound_https" {
  group     = ibm_is_security_group.vsi.id
  direction = "inbound"
  remote    = "0.0.0.0/0"
  protocol  = "tcp"
  port_min  = 443
  port_max  = 443
}

# Allow all outbound (dnf updates, Vault API calls, IBM Cloud API)
resource "ibm_is_security_group_rule" "vsi_outbound_all" {
  group     = ibm_is_security_group.vsi.id
  direction = "outbound"
  remote    = "0.0.0.0/0"
}
