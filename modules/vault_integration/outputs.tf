# ---------------------------------------------------------------
# modules/vault_integration/outputs.tf
# ---------------------------------------------------------------

output "db_username" {
  description = "Database username read from Vault"
  value       = data.vault_kv_secret_v2.app_credentials.data["db_username"]
  sensitive   = true
}

output "db_password" {
  description = "Database password read from Vault"
  value       = data.vault_kv_secret_v2.app_credentials.data["db_password"]
  sensitive   = true
}

output "app_api_key" {
  description = "Application API key read from Vault"
  value       = data.vault_kv_secret_v2.app_credentials.data["app_api_key"]
  sensitive   = true
}

output "secret_version" {
  description = "Current version of the Vault secret"
  value       = data.vault_kv_secret_v2.app_credentials.version
}
