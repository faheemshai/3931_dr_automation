# ---------------------------------------------------------------
# modules/vsi/main.tf
# IBM Cloud Virtual Server Instances
# Profile : cx2-2x4  (2 vCPU / 4 GB RAM)
# Image   : Packer-built RHEL 9.2 golden image (resolved by ID)
# Resource group: var.ibm_resource_group_id
#                 = 90733208e12b46eda9c4fbc130b8e426 (dedicated lab account)
#
# SSH public key is injected from Vault via the vpc module.
# Each VSI is registered as a pool member of the IBM Cloud LB.
# ---------------------------------------------------------------

locals {
  name_prefix = "${var.project}-${var.environment}"
}

# ── Look up the Packer golden image by ID ───────────────────────
# image_id is set dynamically from HCP Packer or manually overridden.
data "ibm_is_image" "golden" {
  identifier = var.image_id
}

# ── VSI instances ────────────────────────────────────────────────
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
  })

  # DR tags — failover scripts query these to find and activate DR VSIs
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

# ── LB Pool Members – register each VSI with the back-end pool ───
resource "ibm_is_lb_pool_member" "app" {
  count          = var.vsi_count
  lb             = var.lb_id
  pool           = var.lb_pool_id
  port           = var.app_port
  target_address = ibm_is_instance.app[count.index].primary_network_interface[0].primary_ip[0].address
  weight         = 50

  depends_on = [ibm_is_instance.app]
}
