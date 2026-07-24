#!/bin/bash
# ---------------------------------------------------------------
# User Data – injected credentials come from HashiCorp Vault
# via the Terraform Vault provider at plan/apply time.
#
# ⚠️  DEMO HARDCODED VALUES BELOW – move to Vault before go-live
# ---------------------------------------------------------------
set -euo pipefail

# ─── Write app config from Vault-supplied vars ──────────────────
cat > /etc/app/env <<EOF
APP_ENV=${environment}
APP_PROJECT=${project}

# Database credentials  ← Vault: kv/ent-demo/app/credentials
DB_USERNAME=${db_username}
DB_PASSWORD=${db_password}

# Third-party API key   ← Vault: kv/ent-demo/app/credentials
APP_API_KEY=${app_api_key}
EOF

chmod 600 /etc/app/env

# ─── Install and start the demo app ─────────────────────────────
yum update -y
yum install -y amazon-cloudwatch-agent

# Source credentials and run the app
source /etc/app/env
# ... start your application process here ...

echo "Bootstrap complete for ${project}-${environment}"
