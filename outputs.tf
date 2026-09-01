# ---------------------------------------------------------------
# outputs.tf  –  LAB-3931 DR Automation
# ---------------------------------------------------------------

# ── PRIMARY us-south ─────────────────────────────────────────────
output "primary_vpc_id" {
  description = "Primary VPC ID (us-south)"
  value       = module.networking_primary.vpc_id
}

output "primary_subnet_id" {
  description = "Primary subnet ID (us-south)"
  value       = module.networking_primary.subnet_id
}

output "primary_lb_hostname" {
  description = "Primary ALB hostname — DNS entry for normal traffic"
  value       = module.alb_primary.lb_hostname
}

output "primary_vsi_ids" {
  description = "Primary VSI instance IDs"
  value       = module.vsi_primary.vsi_ids
}

output "primary_vsi_private_ips" {
  description = "Primary VSI private IPs"
  value       = module.vsi_primary.vsi_private_ips
}

# ── DR eu-de ─────────────────────────────────────────────────────
output "dr_vpc_id" {
  description = "DR VPC ID (eu-de)"
  value       = var.DR_infra ? module.networking_dr[0].vpc_id : ""
}

output "dr_subnet_id" {
  description = "DR subnet ID (eu-de)"
  value       = var.DR_infra ? module.networking_dr[0].subnet_id : ""
}

output "dr_lb_hostname" {
  description = "DR ALB hostname — DNS entry for failover traffic"
  value       = var.DR_infra ? module.alb_dr[0].lb_hostname : ""
}

output "dr_vsi_ids" {
  description = "DR VSI instance IDs"
  value       = var.DR_infra ? module.vsi_dr[0].vsi_ids : []
}

output "dr_vsi_private_ips" {
  description = "DR VSI private IPs"
  value       = var.DR_infra ? module.vsi_dr[0].vsi_private_ips : []
}

# ── Vault metadata ───────────────────────────────────────────────
output "vault_secret_version" {
  description = "Vault KV secret version used for this run — proves dynamic creds"
  value       = module.vault_integration.secret_version
}

# ── Golden image traceability ────────────────────────────────────
output "golden_image_primary" {
  description = "Packer golden image ID deployed to primary region"
  value       = local.image_id_primary
}

output "golden_image_dr" {
  description = "Packer golden image ID deployed to DR region"
  value       = local.image_id_dr
}
