# ---------------------------------------------------------------
# modules/vsi/main.tf
# 2 × IBM Cloud Virtual Server Instances (fixed count, no ASG)
# Image  : ibm-centos-stream-9-amd64-17
# Profile: bx2-2x8 (Flex | 2 vCPU / 8 GB RAM)
# Zone   : eu-de-2
#
# SSH public key is injected from Vault Enterprise via the
# vpc module (ibm_is_ssh_key.vault_key).
#
# Each VSI is registered as a pool member of the IBM Cloud LB.
# ---------------------------------------------------------------

locals {
  name_prefix = "${var.project}-${var.environment}"
}

# ── Look up the CentOS Stream 9 stock image ───────────────────────
data "ibm_is_image" "centos" {
  name = var.image_name
}

# ── 2 Virtual Server Instances ───────────────────────────────────
resource "ibm_is_instance" "app" {
  count   = var.vsi_count
  name    = "${local.name_prefix}-vsi-${count.index + 1}"
  profile = var.vsi_profile
  image   = data.ibm_is_image.centos.id
  zone    = var.ibm_zone

  vpc  = var.vpc_id
  keys = [var.ssh_key_id]

  primary_network_interface {
    subnet          = var.subnet_id
    security_groups = [var.vsi_sg_id]
  }

  # ── User-data: install nginx + basic web page ─────────────────
  user_data = templatefile("${path.module}/templates/user_data.sh.tpl", {
    project     = var.project
    environment = var.environment
    instance_num = count.index + 1
  })

  tags = ["project:${var.project}", "env:${var.environment}", "managed-by:terraform", "index:${count.index + 1}"]
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
