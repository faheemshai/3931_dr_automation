# ---------------------------------------------------------------
# modules/vault_integration/main.tf
#
# READ-ONLY — TFE Dynamic Credentials (scoped JWT token).
#
# The TFE JWT role is bound to tfc-policy, which grants:
#   path "kv/data/terraform"     { capabilities = ["read"] }
#   path "kv/metadata/terraform" { capabilities = ["read"] }
#
# Creating or modifying mounts requires sys/mounts write permission,
# which a scoped TFE token intentionally does NOT have.
# → The vault_mount resource has been removed.
# → The KV v2 mount "kv" must exist in Vault before running TFE.
#   A Vault admin creates it once:
#     vault secrets enable -path=kv kv-v2
#
# What this module does at run-time (read-only):
#   1. Reads the "terraform" secret from the existing kv mount
#   2. Outputs ssh_public_key  → vpc module → ibm_is_ssh_key
#   3. ibm_api_key is read separately in providers.tf (root)
#
# ── One-time Vault admin setup ─────────────────────────────────
#   vault secrets enable -namespace=admin -path=kv kv-v2
#
#   vault kv put -namespace=admin -mount=kv IBM_cloud \
#     public_key="$(cat ~/.ssh/ent_demo_ed25519.pub)" \
#     ibm_api_key="<your-ibm-cloud-api-key>"
#
# ── Required Vault policy (tfc-policy) ────────────────────────
#   path "kv/data/IBM_cloud"     { capabilities = ["read"] }
#   path "kv/metadata/IBM_cloud" { capabilities = ["read"] }
# ---------------------------------------------------------------

# ── Read the secret (ssh public key + ibm api key) ────────────────
# The KV v2 mount "kv" and secret "terraform" must already exist.
data "vault_kv_secret_v2" "ssh_keypair" {
  mount = var.kv_mount
  name  = var.secret_path
}
