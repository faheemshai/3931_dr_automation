# ---------------------------------------------------------------
# modules/alb/main.tf
# IBM Cloud Application Load Balancer (public)
# Pool → round-robin HTTP → health-checked member registration
# Members are attached from the VSI module via pool_id output.
# ---------------------------------------------------------------

locals {
  name_prefix = "${var.project}-${var.environment}"
}

# ── Look up the subnet to place the LB in ────────────────────────
data "ibm_is_subnet" "app" {
  identifier = var.subnet_id
}

# ── Application Load Balancer ─────────────────────────────────────
resource "ibm_is_lb" "this" {
  name    = "${local.name_prefix}-lb"
  subnets = [var.subnet_id]
  type    = "public"

  tags = ["project:${var.project}", "env:${var.environment}", "managed-by:terraform"]
}

# ── Back-end Pool ─────────────────────────────────────────────────
resource "ibm_is_lb_pool" "app" {
  lb                 = ibm_is_lb.this.id
  name               = "${local.name_prefix}-pool"
  protocol           = "http"
  algorithm          = "round_robin"
  health_delay       = 30
  health_retries     = 3
  health_timeout     = 5
  health_type        = "http"
  health_monitor_url = var.health_check_path
  health_monitor_port = var.app_port
}

# ── Front-end Listener (HTTP:80 → pool) ──────────────────────────
resource "ibm_is_lb_listener" "http" {
  lb           = ibm_is_lb.this.id
  port         = 80
  protocol     = "http"
  default_pool = ibm_is_lb_pool.app.id
}
