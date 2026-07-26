# ---------------------------------------------------------------
# modules/vsi/outputs.tf
# ---------------------------------------------------------------

output "vsi_ids" {
  description = "List of VSI instance IDs"
  value       = ibm_is_instance.app[*].id
}

output "vsi_names" {
  description = "List of VSI instance names"
  value       = ibm_is_instance.app[*].name
}

output "vsi_private_ips" {
  description = "Private IP addresses of the VSI instances"
  value       = [for inst in ibm_is_instance.app : inst.primary_network_interface[0].primary_ip[0].address]
}

output "pool_member_ids" {
  description = "LB pool member IDs"
  value       = ibm_is_lb_pool_member.app[*].id
}
