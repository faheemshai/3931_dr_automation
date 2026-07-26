# ---------------------------------------------------------------
# modules/vault_integration/outputs.tf
# ---------------------------------------------------------------

output "ssh_public_key" {
  description = "SSH public key read from Vault — registered as IBM Cloud SSH key for VSI access"
  value       = data.vault_kv_secret_v2.ssh_keypair.data["public_key"]
  sensitive   = true
}

output "secret_version" {
  description = "Current version of the SSH keypair secret in Vault"
  value       = data.vault_kv_secret_v2.ssh_keypair.version
}
