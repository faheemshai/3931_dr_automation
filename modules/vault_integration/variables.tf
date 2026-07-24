# ---------------------------------------------------------------
# modules/vault_integration/variables.tf
# ---------------------------------------------------------------

variable "project" {
  description = "Short project name used for tagging / metadata"
  type        = string
}

variable "environment" {
  description = "Deployment environment label (prod / staging / dev)"
  type        = string
}

variable "kv_mount" {
  description = "KV v2 secrets engine mount path in Vault (e.g. kv/ent-demo)"
  type        = string
}

variable "secret_path" {
  description = "Path within the KV mount where application credentials are stored (e.g. app/credentials)"
  type        = string
}
