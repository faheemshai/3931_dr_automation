# ---------------------------------------------------------------
# modules/vault_integration/variables.tf
# ---------------------------------------------------------------

variable "project" {
  type = string
}

variable "environment" {
  type = string
}

variable "kv_mount" {
  description = "KV v2 mount path in Vault (e.g. kv/ent-demo)"
  type        = string
}

variable "secret_path" {
  description = "Path within the mount (e.g. app/credentials)"
  type        = string
}
