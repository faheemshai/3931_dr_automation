# ---------------------------------------------------------------
# modules/vault_integration/main.tf
#
# This module:
#  1. Ensures the KV v2 mount exists in Vault Enterprise
#  2. Writes placeholder secrets (demo phase — replace with real
#     values in Vault before go-live)
#  3. Reads back:
#       - SSH public key  → registered as ibm_is_ssh_key
#       - IBM Cloud API key → wired into the ibm provider
#
# Demo flow:
#   Phase A – "Before Vault" : placeholder values written here
#   Phase B – "After Vault"  : load real values with vault kv put,
#                              then re-run terraform apply
#
# ⚠️  To load real values into Vault:
#   vault kv put kv/ent-demo/ssh/keypair \
#     public_key="ssh-rsa AAAA... user@host" \
#     ibm_api_key="<your-ibm-cloud-api-key>"
# ---------------------------------------------------------------

# ── Ensure the KV v2 mount exists ────────────────────────────────
resource "vault_mount" "kv" {
  path        = var.kv_mount
  type        = "kv"
  options     = { version = "2" }
  description = "KV v2 mount for ${var.project} secrets"
}

# ── Write DEMO placeholder secrets (Phase A) ─────────────────────
# ⚠️  DEMO ONLY — both values are placeholders.
#     The ignore_changes lifecycle ensures Terraform never overwrites
#     real values that have been loaded externally into Vault.
resource "vault_kv_secret_v2" "ssh_keypair" {
  mount               = vault_mount.kv.path
  name                = var.secret_path
  delete_all_versions = false

  data_json = jsonencode({
    # ── SSH public key (replace in Vault before go-live) ──────────
    public_key  = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC0g28...DEMO-REPLACE-ME demo@ent-demo"
    # ── IBM Cloud API key (replace in Vault before go-live) ───────
    ibm_api_key = "DEMO-IBM-API-KEY-REPLACE-ME"
  })

  lifecycle {
    # Prevent Terraform from overwriting real secrets loaded externally
    ignore_changes = [data_json]
  }
}

# ── Read back all secrets ────────────────────────────────────────
data "vault_kv_secret_v2" "ssh_keypair" {
  mount = vault_mount.kv.path
  name  = var.secret_path

  depends_on = [vault_kv_secret_v2.ssh_keypair]
}
