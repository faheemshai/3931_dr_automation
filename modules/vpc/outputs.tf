# ---------------------------------------------------------------
# modules/vpc/outputs.tf
# ---------------------------------------------------------------

output "vpc_id" {
  description = "ID of the VPC (existing or newly created)"
  value       = local.vpc_id
}

output "subnet_id" {
  description = "ID of the subnet (existing or newly created)"
  value       = local.subnet_id
}

output "subnet_crn" {
  description = "CRN of the subnet"
  value = (
    local.use_subnet_by_id   ? data.ibm_is_subnet.by_id[0].crn   :
    local.use_subnet_by_name ? data.ibm_is_subnet.by_name[0].crn :
    ibm_is_subnet.new[0].crn
  )
}

output "ssh_key_id" {
  description = "ID of the IBM Cloud SSH key registered from Vault"
  value       = ibm_is_ssh_key.vault_key.id
}
