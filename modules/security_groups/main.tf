# ---------------------------------------------------------------
# modules/security_groups/main.tf
# IBM Cloud VPC Security Groups (IBM provider >= 1.65):
#   lb-sg  : inbound port 80 from 0.0.0.0/0  (public-facing LB)
#   vsi-sg : inbound app_port from lb-sg + SSH from bastion CIDR
#
# NOTE: The deprecated tcp{} nested block has been replaced with
#   top-level  protocol + port_min + port_max  arguments.
# ---------------------------------------------------------------

locals {
  name_prefix = "${var.project}-${var.environment}"
}

# ── Load Balancer Security Group ─────────────────────────────────
resource "ibm_is_security_group" "lb" {
  name           = "${local.name_prefix}-lb-sg"
  vpc            = var.vpc_id
  resource_group = var.ibm_resource_group_id

  tags = ["project:${var.project}", "env:${var.environment}", "tier:lb"]
}

# Allow inbound HTTP (port 80) from internet
resource "ibm_is_security_group_rule" "lb_inbound_http" {
  group     = ibm_is_security_group.lb.id
  direction = "inbound"
  remote    = "0.0.0.0/0"
  protocol  = "tcp"
  port_min  = 80
  port_max  = 80
}

# Allow all outbound from LB (to reach VSIs)
# protocol is intentionally omitted — omitting it means allow all protocols
resource "ibm_is_security_group_rule" "lb_outbound_all" {
  group     = ibm_is_security_group.lb.id
  direction = "outbound"
  remote    = "0.0.0.0/0"
}

# ── VSI Security Group ────────────────────────────────────────────
resource "ibm_is_security_group" "vsi" {
  name           = "${local.name_prefix}-vsi-sg"
  vpc            = var.vpc_id
  resource_group = var.ibm_resource_group_id

  tags = ["project:${var.project}", "env:${var.environment}", "tier:app"]
}

# Allow inbound app traffic from the LB security group only
resource "ibm_is_security_group_rule" "vsi_inbound_app" {
  group     = ibm_is_security_group.vsi.id
  direction = "inbound"
  remote    = ibm_is_security_group.lb.id
  protocol  = "tcp"
  port_min  = var.app_port
  port_max  = var.app_port
}

# Allow inbound SSH from bastion / VPN CIDR
resource "ibm_is_security_group_rule" "vsi_inbound_ssh" {
  group     = ibm_is_security_group.vsi.id
  direction = "inbound"
  remote    = var.ssh_allowed_cidr
  protocol  = "tcp"
  port_min  = 22
  port_max  = 22
}

# Allow all outbound from VSI (dnf updates, Vault calls, etc.)
# protocol is intentionally omitted — omitting it means allow all protocols
resource "ibm_is_security_group_rule" "vsi_outbound_all" {
  group     = ibm_is_security_group.vsi.id
  direction = "outbound"
  remote    = "0.0.0.0/0"
}
