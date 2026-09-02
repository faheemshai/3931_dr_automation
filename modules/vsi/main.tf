# ---------------------------------------------------------------
# modules/vsi/main.tf
# IBM Cloud Virtual Server Instances with Floating IPs
#
# Architecture: NO load balancer — each VSI gets its own Floating IP
# for direct public access. This is the correct model for a lab
# environment with per-student VSIs.
#
# Profile : cx2-2x4  (2 vCPU / 4 GB RAM)
# Image   : Packer-built RHEL 9.8 golden image (resolved by ID)
# Access  : SSH + HTTP via Floating IP (public internet routable)
# ---------------------------------------------------------------

locals {
  name_prefix = "${var.project}-${var.environment}"
}

# ── Look up the Packer golden image by ID ────────────────────────
data "ibm_is_image" "golden" {
  identifier = var.image_id
}

# ── VSI instances ─────────────────────────────────────────────────
resource "ibm_is_instance" "app" {
  count          = var.vsi_count
  name           = "${local.name_prefix}-vsi-${count.index + 1}"
  profile        = var.vsi_profile
  image          = data.ibm_is_image.golden.id
  zone           = var.ibm_zone
  resource_group = var.ibm_resource_group_id

  vpc  = var.vpc_id
  keys = [var.ssh_key_id]

  primary_network_interface {
    subnet          = var.subnet_id
    security_groups = [var.vsi_sg_id]
  }

  user_data = templatefile("${path.module}/templates/user_data.sh.tpl", {
    project      = var.project
    environment  = var.environment
    instance_num = count.index + 1
    ibm_region   = var.ibm_region
    ibm_zone     = var.ibm_zone
    image_name   = data.ibm_is_image.golden.name
    vsi_profile  = var.vsi_profile
  })

  tags = [
    "project:${var.project}",
    "env:${var.environment}",
    "managed-by:terraform",
    "dr-role:${var.dr_role}",
    "dr-pair:${var.dr_pair}",
    "golden-image:${var.image_id}",
    "index:${count.index + 1}",
  ]
}

# ── Floating IPs — one per VSI ────────────────────────────────────
# Each VSI gets its own public IP — no ALB required.
# Students access their VSI directly via the floating IP.
resource "ibm_is_floating_ip" "app" {
  count          = var.vsi_count
  name           = "${local.name_prefix}-fip-${count.index + 1}"
  target         = ibm_is_instance.app[count.index].primary_network_interface[0].id
  resource_group = var.ibm_resource_group_id

  tags = [
    "project:${var.project}",
    "env:${var.environment}",
    "managed-by:terraform",
    "dr-role:${var.dr_role}",
    "index:${count.index + 1}",
  ]

  depends_on = [ibm_is_instance.app]
}
