# ---------------------------------------------------------------
# modules/vault_integration/main.tf
#
# This module:
#  1. Ensures the KV v2 mount exists in Vault Enterprise
#  2. Writes a placeholder SSH key pair (demo phase — replace with
#     a real key before go-live by writing it to Vault directly)
#  3. Reads back the SSH public key so it can be registered in
#     IBM Cloud as an SSH key for VSI provisioning
#
# Demo flow:
#   Phase A – "Before Vault" : placeholder keypair written here
#   Phase B – "After Vault"  : real key loaded via Vault UI/CLI;
#                              comment out the vault_kv_secret_v2
#                              write block and re-run apply
# ---------------------------------------------------------------

# ── Ensure the KV v2 mount exists ────────────────────────────────
resource "vault_mount" "kv" {
  path        = var.kv_mount
  type        = "kv"
  options     = { version = "2" }
  description = "KV v2 mount for ${var.project} secrets"
}

# ── Write DEMO placeholder SSH keypair (Phase A) ─────────────────
# ⚠️  DEMO ONLY — replace with a real key pair in Vault before go-live
# Write your real public key with:
#   vault kv put kv/ent-demo/ssh/keypair \
#     public_key="ssh-rsa AAAA... user@host"
resource "vault_kv_secret_v2" "ssh_keypair" {
  mount               = vault_mount.kv.path
  name                = var.secret_path
  delete_all_versions = false

  data_json = jsonencode({
    # ── Placeholder public key (replace in Vault before go-live) ──
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC0g28...DEMO-REPLACE-ME demo@ent-demo"
  })

  lifecycle {
    # Prevent Terraform from overwriting a real key that was loaded externally
    ignore_changes = [data_json]
  }
}

# ── Read back the SSH public key ────────────────────────────────
data "vault_kv_secret_v2" "ssh_keypair" {
  mount = vault_mount.kv.path
  name  = var.secret_path

  depends_on = [vault_kv_secret_v2.ssh_keypair]
}
