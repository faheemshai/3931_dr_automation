# Terraform Enterprise + Vault Enterprise — IBM Cloud Demo

A **production-grade** Terraform module suite that deploys two IBM Cloud VSIs behind a public Application Load Balancer in **eu-de-2** (Frankfurt), demonstrating a full zero-static-credential integration between **Terraform Enterprise** and **HashiCorp Vault Enterprise** using **Dynamic Credentials (JWT / Workload Identity)**.

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  Terraform Enterprise                   │
│                                                         │
│  Plan/Apply run                                         │
│     │                                                   │
│     ├─ mints short-lived workload-identity JWT          │
│     │                                                   │
│     └─ injects env vars:                               │
│          TFC_VAULT_ADDR, TFC_VAULT_NAMESPACE            │
│          TFC_VAULT_PROVIDER_AUTH, TFC_VAULT_RUN_ROLE    │
└────────────────────┬────────────────────────────────────┘
                     │ JWT exchange
                     ▼
        ┌────────────────────────┐
        │   Vault Enterprise     │
        │   JWT auth method      │
        │                        │
        │  kv/ent-demo/          │
        │    ssh/keypair         │
        │      ├ public_key      │──────────────────────┐
        │      └ ibm_api_key     │──────────────┐       │
        └────────────────────────┘              │       │
                                                │       │
                                     ┌──────────▼──┐    │
                                     │ provider    │    │
                                     │  "ibm"      │    │
                                     └──────────┬──┘    │
                                                │       │
                        ┌───────────────────────▼───────▼──────┐
                        │           IBM Cloud  eu-de-2          │
                        │                                       │
                        │   ┌──────────────────────────────┐   │
                        │   │  Application Load Balancer   │   │
                        │   │    public  |  HTTP :80        │   │
                        │   └──────────┬───────────────────┘   │
                        │              │ round-robin            │
                        │    ┌─────────┴─────────┐             │
                        │    ▼                   ▼             │
                        │  ┌──────────┐   ┌──────────┐         │
                        │  │  VSI 1   │   │  VSI 2   │         │
                        │  │ bx2-2x8  │   │ bx2-2x8  │         │
                        │  │ nginx    │   │ nginx    │         │
                        │  │ SSH key ◄────── from Vault        │
                        │  └──────────┘   └──────────┘         │
                        │    Default VPC  |  Subnet 10.240.2/24 │
                        └───────────────────────────────────────┘
```

### Resource inventory

| Layer | IBM Cloud Resource |
|---|---|
| **Networking** | Default VPC (looked up by name), 1× Subnet `10.240.2.0/24` in `eu-de-2` |
| **SSH Access** | `ibm_is_ssh_key` — public key loaded from Vault KV v2 at apply time |
| **Security** | LB Security Group (port 80 public), VSI Security Group (app from LB + SSH from bastion CIDR) |
| **Compute** | 2× `ibm_is_instance` — profile `bx2-2x8`, image `ibm-centos-stream-9-amd64-17` |
| **Load Balancer** | `ibm_is_lb` (public) + `ibm_is_lb_pool` (round-robin HTTP) + `ibm_is_lb_listener` (port 80) |
| **Secrets** | Vault Enterprise KV v2 → IBM API key + SSH public key, zero static tokens |

---

## Credential Flow — Zero Static Secrets

```
Nothing sensitive lives in code, tfvars, or environment variables on the operator's machine.
```

| Credential | Where it lives | How it reaches Terraform |
|---|---|---|
| Vault auth token | Never exists as a static value | TFE mints a short-lived JWT; Vault exchanges it for a 20-min scoped token |
| IBM Cloud API key | `kv/ent-demo/ssh/keypair` in Vault KV v2 | Read by `data.vault_kv_secret_v2` in `providers.tf`; fed into `provider "ibm"` |
| SSH public key | `kv/ent-demo/ssh/keypair` in Vault KV v2 | Read by `module.vault_integration`; registered as `ibm_is_ssh_key` |

---

## Module Structure

```
.
├── main.tf                          # Root — wires all modules
├── variables.tf                     # All input variables
├── outputs.tf                       # Key outputs
├── versions.tf                      # Provider versions + TFE cloud block
├── providers.tf                     # Vault JWT auth + IBM provider bootstrap
├── terraform.tfvars                 # Non-sensitive configuration only
└── modules/
    ├── vault_integration/           # KV v2 mount + secret read (SSH key)
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── vpc/                         # Default VPC lookup, subnet, ibm_is_ssh_key
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── security_groups/             # LB SG + VSI SG + rules
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── alb/                         # IBM Cloud ALB, pool, listener
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── vsi/                         # 2× ibm_is_instance + pool members + nginx user_data
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        └── templates/
            └── user_data.sh.tpl    # dnf install nginx, status page, /health endpoint
```

---

## Prerequisites

```bash
# CLI tools
terraform  >= 1.6
vault      >= 1.15  (Vault Enterprise for namespaces)
ibmcloud   >= 2.x   (optional — for manual verification)

# No credentials needed locally — everything comes from Vault via TFE Dynamic Credentials
```

---

## One-Time Setup

### 1 — Vault admin: enable JWT auth and create the role

```bash
# Enable the JWT auth method (once per Vault cluster)
vault auth enable -path=jwt jwt

# Point it at your TFE instance's OIDC discovery endpoint
vault write auth/jwt/config \
  oidc_discovery_url="https://<TFE_HOSTNAME>/.well-known/openid-configuration" \
  bound_issuer="https://<TFE_HOSTNAME>"

# Create a role for this workspace
vault write auth/jwt/role/tfe-ibm-demo \
  role_type="jwt" \
  bound_audiences="vault.workload.identity" \
  user_claim="terraform_full_workspace" \
  token_policies="ent-demo-policy" \
  token_ttl="20m" \
  token_max_ttl="30m"
```

### 2 — Vault admin: create the policy

```hcl
# ent-demo-policy.hcl
path "kv/data/ent-demo/ssh/keypair" {
  capabilities = ["read"]
}

path "sys/mounts/kv/ent-demo" {
  capabilities = ["read"]
}
```

```bash
vault policy write ent-demo-policy ent-demo-policy.hcl
```

### 3 — Vault admin: write the secrets (once)

```bash
vault kv put kv/ent-demo/ssh/keypair \
  public_key="$(cat ~/.ssh/id_rsa.pub)" \
  ibm_api_key="<your-ibm-cloud-api-key>"

# Verify
vault kv get kv/ent-demo/ssh/keypair
```

### 4 — TFE: set workspace environment variables

Set these in **TFE UI → Workspace → Variables → Environment Variables**.
Mark each one **Sensitive**.

| Variable | Value | Description |
|---|---|---|
| `TFC_VAULT_PROVIDER_AUTH` | `true` | Enables Dynamic Credentials for this workspace |
| `TFC_VAULT_ADDR` | `https://vault.example.com:8200` | Vault Enterprise URL |
| `TFC_VAULT_NAMESPACE` | `admin/ent-demo` | Vault Enterprise namespace |
| `TFC_VAULT_RUN_ROLE` | `tfe-ibm-demo` | JWT role name created in step 1 |

### 5 — TFE: configure the workspace

```bash
# Update versions.tf with your org and workspace name, then push
git add .
git commit -m "feat: IBM Cloud VSI demo with Vault Enterprise dynamic credentials"
git push
```

Confirm `versions.tf` `cloud {}` block matches your TFE org/workspace:

```hcl
cloud {
  organization = "my-org"           # ← your TFE organisation
  workspaces {
    name = "prod-ibm-vsi-demo"      # ← your workspace name
  }
}
```

---

## Running the Demo

```bash
# 1. Initialise (connects to TFE remote backend)
terraform init

# 2. Plan — TFE automatically:
#    a) mints a workload-identity JWT for this run
#    b) exchanges it with Vault for a 20-min scoped token
#    c) reads ibm_api_key + public_key from Vault KV
#    d) configures the ibm provider with the API key
terraform plan

# 3. Apply
terraform apply

# 4. Get the LB hostname and open in a browser
terraform output lb_hostname
# → open  http://<lb_hostname>
#   You will see the nginx status page for each VSI showing:
#   project, environment, instance number, hostname, private IP
```

---

## Updating Secrets in Vault

To rotate the IBM API key or SSH key without touching Terraform code:

```bash
# Rotate IBM API key
vault kv patch kv/ent-demo/ssh/keypair \
  ibm_api_key="<new-ibm-cloud-api-key>"

# Rotate SSH key
vault kv patch kv/ent-demo/ssh/keypair \
  public_key="$(cat ~/.ssh/new_key.pub)"

# Check the new version number
vault kv metadata get kv/ent-demo/ssh/keypair

# Re-run Terraform to pick up the new values
# (TFE will mint a fresh JWT automatically on the next run)
terraform apply
```

To roll back to a previous secret version:

```bash
vault kv rollback -version=1 kv/ent-demo/ssh/keypair
terraform apply
```

---

## Vault Useful Commands

```bash
# List all secrets under the mount
vault kv list kv/ent-demo/

# Read the current secret
vault kv get kv/ent-demo/ssh/keypair

# View full version history
vault kv metadata get kv/ent-demo/ssh/keypair

# Enable file audit log (show the full access trail during demo)
vault audit enable file file_path=/tmp/vault-audit.log
tail -f /tmp/vault-audit.log | jq .request.path
```

---

## Inputs

| Name | Default | Description |
|---|---|---|
| `ibm_region` | `eu-de` | IBM Cloud region |
| `ibm_zone` | `eu-de-2` | IBM Cloud zone |
| `environment` | `prod` | Environment label (`prod` / `staging` / `dev`) |
| `project` | `ent-demo` | Project short name used in resource naming |
| `subnet_cidr` | `10.240.2.0/24` | Subnet CIDR in eu-de-2 |
| `ssh_allowed_cidr` | `10.0.0.0/8` | CIDR allowed to SSH to VSIs |
| `app_port` | `80` | Port nginx listens on |
| `health_check_path` | `/` | LB health monitor path |
| `vsi_count` | `2` | Number of VSI instances (fixed) |
| `vsi_profile` | `bx2-2x8` | VSI profile (Flex \| 2 vCPU / 8 GB RAM) |
| `image_name` | `ibm-centos-stream-9-amd64-17` | IBM Cloud stock image |
| `vault_jwt_auth_path` | `jwt` | Vault JWT auth method mount path |
| `vault_jwt_role` | `tfe-ibm-demo` | Vault JWT role for this TFE workspace |
| `vault_mount_path` | `kv/ent-demo` | Vault KV v2 mount path |
| `vault_secret_path` | `ssh/keypair` | Secret path within the KV mount |

## Outputs

| Name | Description |
|---|---|
| `vpc_id` | ID of the default IBM Cloud VPC |
| `subnet_id` | ID of the subnet created in eu-de-2 |
| `ssh_key_id` | IBM Cloud SSH key ID (public key from Vault) |
| `lb_hostname` | Public hostname of the Application Load Balancer |
| `lb_id` | Load Balancer resource ID |
| `vsi_ids` | List of VSI instance IDs |
| `vsi_private_ips` | Private IP addresses of the two VSIs |
| `vault_secret_version` | Current KV v2 version of the secret in Vault |

---

## Security Notes

| Control | Implementation |
|---|---|
| No static Vault token | TFE Dynamic Credentials (JWT) — token TTL 20 min, auto-expires |
| No IBM API key in code | Read from Vault KV v2 at plan/apply time only |
| No secrets in `terraform.tfvars` | File contains only non-sensitive configuration |
| SSH key from Vault | `ibm_is_ssh_key` registered directly from Vault — private key never touches Terraform state |
| VSI SSH access locked to bastion CIDR | `ssh_allowed_cidr = "10.0.0.0/8"` — restrict before go-live |
| LB only exposes port 80 | VSIs not directly reachable from internet |
| VSI SG allows app traffic from LB SG only | Source is a security group reference, not a CIDR |
| Vault policy least-privilege | TFE JWT role policy grants `read` on the single secret path only |
| All credential outputs marked sensitive | `sensitive = true` on all Vault-sourced outputs |
