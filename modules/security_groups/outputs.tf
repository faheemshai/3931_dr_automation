# ---------------------------------------------------------------
# modules/security_groups/outputs.tf
# ---------------------------------------------------------------

output "lb_sg_id" {
  description = "ID of the load balancer security group"
  value       = ibm_is_security_group.lb.id
}

output "vsi_sg_id" {
  description = "ID of the VSI application security group"
  value       = ibm_is_security_group.vsi.id
}
