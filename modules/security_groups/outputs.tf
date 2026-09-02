# ---------------------------------------------------------------
# modules/security_groups/outputs.tf
# ---------------------------------------------------------------

output "vsi_sg_id" {
  description = "ID of the VSI security group"
  value       = ibm_is_security_group.vsi.id
}
