# ---------------------------------------------------------------
# modules/vault_integration/main.tf
#
# This module:
#  1. Reads an existing KV v2 secret from Vault (post-migration)
#  2. Writes dummy/placeholder secrets during the demo phase
#     (remove the writes once you've loaded real values into Vault)
#
# Demo flow:
#   Phase A – "Before Vault" : values are hardcoded in terraform.tfvars
#   Phase B – "After Vault"  : values are stored in Vault; this module
#                               reads them and passes them to the EC2 module
# ---------------------------------------------------------------

# ── Ensure the KV v2 mount exists ────────────────────────────────
resource "vault_mount" "kv" {
  path        = var.kv_mount
  type        = "kv"
  options     = { version = "2" }
  description = "KV v2 mount for ${var.project} application secrets"
}

# ── Write DEMO placeholder secrets (Phase A) ─────────────────────
# ⚠️  HARDCODED FOR DEMO PURPOSES ONLY
# These represent the "bad" state you are migrating AWAY from.
# Once real values are in Vault, comment-out / remove this resource.
resource "vault_kv_secret_v2" "app_credentials" {
  mount               = vault_mount.kv.path
  name                = var.secret_path
  delete_all_versions = false

  data_json = jsonencode({
    # ── Dummy credentials (replace in Vault UI before go-live) ───
    db_username = "prod_db_user"                   # HARDCODED DEMO
        # HARDCODED DEMO breakglass
    app_api_key = "sk-demo-abc123XYZ-REPLACE-ME"   # HARDCODED DEMO
    ssh_key_id  = "prod-key-pair-demo"             # HARDCODED DEMO
  })
}

# ── Read back the secret (Phase B – used in EC2 user_data) ────────
data "vault_kv_secret_v2" "app_credentials" {
  mount = vault_mount.kv.path
  name  = var.secret_path

  depends_on = [vault_kv_secret_v2.app_credentials]
}
