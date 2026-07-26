# ---------------------------------------------------------------
# modules/vpc/outputs.tf
# ---------------------------------------------------------------

output "vpc_id" {
  description = "ID of the default VPC"
  value       = data.ibm_is_vpc.default.id
}

output "subnet_id" {
  description = "ID of the subnet created in eu-de-2"
  value       = ibm_is_subnet.app.id
}

output "subnet_crn" {
  description = "CRN of the subnet"
  value       = ibm_is_subnet.app.crn
}

output "ssh_key_id" {
  description = "ID of the IBM Cloud SSH key registered from Vault"
  value       = ibm_is_ssh_key.vault_key.id
}
