# Enterprise Terraform + HashiCorp Vault Integration Demo

A **production-grade** Terraform module suite that deploys a full AWS stack and demonstrates the complete lifecycle of migrating hardcoded credentials into HashiCorp Vault Enterprise.

---

## Architecture

```
Internet
   │
   ▼
[ALB - public subnets]
   │  HTTP 80 → redirect 301
   │  HTTPS 443 → forward
   ▼
[EC2 ASG - private subnets]   ←── credentials injected via Vault
   │
   ▼
[VPC Flow Logs → CloudWatch]
```

| Layer | Resource |
|---|---|
| **Network** | VPC, 2× Public subnets, 2× Private subnets, IGW, 2× NAT GW (HA), Route Tables |
| **Security** | ALB SG (80/443 open), App SG (ALB-only + bastion SSH), IMDSv2 enforced, EBS encrypted |
| **Compute** | Launch Template + Auto Scaling Group, Target Tracking (CPU 60%) |
| **Load Balancer** | ALB + S3 access logs (encrypted), TLS 1.3 listener |
| **Secrets** | HashiCorp Vault KV v2 → EC2 user-data injection |
| **Observability** | VPC Flow Logs, CloudWatch Agent, SSM access (no bastion needed) |

---

## Module Structure

```
.
├── main.tf                          # Root – wires all modules
├── variables.tf                     # All input variables
├── outputs.tf                       # Key outputs
├── versions.tf                      # Provider versions (TFE compatible)
├── providers.tf                     # AWS + Vault providers
├── terraform.tfvars                 # Demo configuration
└── modules/
    ├── vpc/                         # VPC, subnets, routes, flow logs
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── security_groups/             # ALB SG + App SG
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── alb/                         # ALB, listeners, TG, S3 logs
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── ec2/                         # Launch Template, ASG, IAM, scaling
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── templates/
    │       └── user_data.sh.tpl     # Credential injection script
    └── vault_integration/           # Vault KV mount, write + read secrets
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

---

## Demo Walkthrough

### Prerequisites

```bash
# Tools
terraform >= 1.6
vault >= 1.15        # or Vault Enterprise
aws-cli >= 2.x

# AWS credentials (any method)
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_DEFAULT_REGION=us-east-1

# Vault token
export TF_VAR_vault_token=<your-vault-token>
```

---

### Phase A – "Before Vault" (hardcoded credentials)

This phase shows the **problem**: dummy credentials are hardcoded inside
`modules/vault_integration/main.tf` in the `vault_kv_secret_v2` resource.

```hcl
# modules/vault_integration/main.tf  (demo bad state)
data_json = jsonencode({
  db_username = "prod_db_user"                   # HARDCODED DEMO
  db_password = "Sup3rS3cr3t!Passw0rd#2024"      # HARDCODED DEMO
  app_api_key = "sk-demo-abc123XYZ-REPLACE-ME"   # HARDCODED DEMO
})
```

```bash
# Start Vault in dev mode (local demo)
vault server -dev -dev-root-token-id=root &
export VAULT_ADDR=http://127.0.0.1:8200
export TF_VAR_vault_token=root

# Init and apply
terraform init
terraform plan
terraform apply
```

**What happens**: Terraform writes the dummy secrets to Vault KV v2,
then immediately reads them back and injects them into the EC2 user-data.
The credentials travel through the Vault provider – they never touch
`terraform.tfvars` or any state file in plaintext (state is marked sensitive).

---

### Phase B – "After Vault" (real credentials in Vault)

Replace the dummy values with your real credentials using the **Vault CLI**:

```bash
# Update DB password
vault kv patch kv/ent-demo/app/credentials \
  db_password="RealPr0ductionP@ssw0rd!"

# Update API key
vault kv patch kv/ent-demo/app/credentials \
  app_api_key="sk-prod-REAL-KEY-HERE"

# Verify
vault kv get kv/ent-demo/app/credentials
```

Now **remove the hardcoded write** from Terraform (comment out the
`vault_kv_secret_v2.app_credentials` resource) so Terraform only **reads**
from Vault:

```bash
terraform apply   # EC2 instances roll via Instance Refresh (rolling, 50% min healthy)
```

---

### Phase C – Terraform Enterprise Integration

1. Push this repo to your TFE/TFC organization
2. Uncomment the `cloud {}` block in `versions.tf`
3. Set workspace variables:
   - `TF_VAR_vault_token` → **sensitive** workspace variable
   - `vault_address` → your Vault Enterprise URL
4. Enable **Vault-backed dynamic provider credentials** (HCP Vault + TFE native integration):
   ```hcl
   # In TFE workspace settings → Vault-backed dynamic credentials
   # Vault manages a short-lived AWS role; no static AWS keys needed
   ```

---

### Vault CLI – Useful Commands for Demo

```bash
# List all secrets
vault kv list kv/ent-demo/

# Read current version
vault kv get kv/ent-demo/app/credentials

# View version history
vault kv metadata get kv/ent-demo/app/credentials

# Roll back to previous version
vault kv rollback -version=1 kv/ent-demo/app/credentials

# Enable audit log (show the trail)
vault audit enable file file_path=/tmp/vault-audit.log
cat /tmp/vault-audit.log | jq .
```

---

## Security Notes

| Control | Status |
|---|---|
| IMDSv2 enforced | ✅ `http_tokens = "required"` |
| EBS encryption | ✅ `encrypted = true` |
| S3 public access blocked | ✅ All four block settings |
| S3 server-side encryption | ✅ AES-256 |
| VPC Flow Logs | ✅ ALL traffic, 30-day retention |
| SSH locked to bastion CIDR | ✅ `10.0.0.0/8` default |
| Vault state sensitivity | ✅ All credential outputs `sensitive = true` |
| TLS 1.3 on ALB | ✅ `ELBSecurityPolicy-TLS13-1-2-2021-06` |

> **ACM Certificate**: Replace the placeholder ARN in `modules/alb/main.tf`
> line ~116 with a real ACM certificate ARN before going live.

---

## Inputs

| Name | Default | Description |
|---|---|---|
| `aws_region` | `us-east-1` | AWS deployment region |
| `environment` | `prod` | Environment label |
| `project` | `ent-demo` | Project short name |
| `vpc_cidr` | `10.0.0.0/16` | VPC CIDR block |
| `instance_type` | `t3.micro` | EC2 instance type |
| `vault_address` | `http://127.0.0.1:8200` | Vault server URL |
| `vault_token` | `""` | Set via `TF_VAR_vault_token` |

## Outputs

| Name | Description |
|---|---|
| `vpc_id` | VPC ID |
| `alb_dns_name` | ALB public DNS |
| `asg_name` | Auto Scaling Group name |
| `vault_secret_version` | Current Vault secret version |
