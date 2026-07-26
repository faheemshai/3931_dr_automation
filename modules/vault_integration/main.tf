# ---------------------------------------------------------------
# modules/vault_integration/main.tf
#
# With TFE Dynamic Credentials this module is READ-ONLY against Vault.
# The short-lived JWT token TFE obtains has a scoped policy — it can
# read secrets but should NOT write them.
#
# What this module does:
#   1. Ensures the KV v2 mount exists (idempotent)
#   2. Reads the ssh/keypair secret — outputs ssh_public_key to the
#      vpc module so it can register ibm_is_ssh_key
#
# The IBM Cloud API key is read in providers.tf (root-level data source)
# and fed directly into the ibm provider — it is NOT re-read here.
#
# ── One-time secret population (run by a Vault admin, not TFE) ────
#   vault kv put kv/ent-demo/ssh/keypair \
#     public_key="$(cat ~/.ssh/id_rsa.pub)" \
#     ibm_api_key="<your-ibm-cloud-api-key>"
#
# ── Required Vault policy for the TFE JWT role ────────────────────
#   path "kv/data/ent-demo/ssh/keypair" {
#     capabilities = ["read"]
#   }
#   path "sys/mounts/kv/ent-demo" {
#     capabilities = ["read"]
#   }
# ---------------------------------------------------------------

# ── Ensure the KV v2 mount exists ────────────────────────────────
# This is a read-safe, idempotent resource — it will not error if the
# mount already exists, and creates it only on first apply by a
# privileged operator token (not the scoped TFE JWT token).
resource "vault_mount" "kv" {
  path        = var.kv_mount
  type        = "kv"
  options     = { version = "2" }
  description = "KV v2 mount for ${var.project} secrets"
}

# ── Read the secret (ssh public key + ibm api key) ────────────────
data "vault_kv_secret_v2" "ssh_keypair" {
  mount = vault_mount.kv.path
  name  = var.secret_path
}
