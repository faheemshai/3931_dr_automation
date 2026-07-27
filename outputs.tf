# ---------------------------------------------------------------
# Root outputs
# ---------------------------------------------------------------

output "vpc_id" {
  description = "ID of the VPC used (existing or newly created)"
  value       = module.networking.vpc_id
}

output "subnet_id" {
  description = "ID of the subnet in eu-de-2 (existing or newly created)"
  value       = module.networking.subnet_id
}

output "ssh_key_id" {
  description = "IBM Cloud SSH key ID (public key loaded from Vault)"
  value       = module.networking.ssh_key_id
}

output "lb_hostname" {
  description = "Public hostname of the IBM Cloud Application Load Balancer"
  value       = module.alb.lb_hostname
}

output "lb_id" {
  description = "ID of the Application Load Balancer"
  value       = module.alb.lb_id
}

output "vsi_ids" {
  description = "List of VSI instance IDs"
  value       = module.vsi.vsi_ids
}

output "vsi_private_ips" {
  description = "Private IP addresses of the VSI instances"
  value       = module.vsi.vsi_private_ips
}

output "vault_secret_version" {
  description = "Current version of the SSH keypair secret in Vault"
  value       = module.vault_integration.secret_version
}
