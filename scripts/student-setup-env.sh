#!/bin/bash
# ---------------------------------------------------------------
# scripts/student-setup-env.sh
#
# Students run this ONCE at the start of the lab.
# It reads all credentials from Vault automatically and sets up
# everything needed for the Packer build.
#
# ⚠️  MUST be run with 'source' (not 'bash') so that exported
#    environment variables (IBM_API_KEY, HCP_CLIENT_ID, etc.)
#    are available in your current shell session.
#
# Prerequisites (instructor provides):
#   - student-sNN.env file (contains VAULT_ADDR + VAULT_TOKEN)
#
# Usage:
#   Step 1:  source scripts/student-tokens/student-sNN.env
#   Step 2:  source scripts/student-setup-env.sh        ← 'source', not 'bash'
#   Step 3:  cd packer && packer init . && packer build -var-file=student.pkrvars.hcl .
# ---------------------------------------------------------------

# Guard: if being run with 'bash' instead of 'source', warn and exit
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  printf "\n  ❌  ERROR: Run this script with 'source', not 'bash':\n"
  printf "       source scripts/student-setup-env.sh\n\n"
  printf "  'bash' runs in a subprocess — exported variables are lost\n"
  printf "  when the script exits. 'source' runs in your current shell.\n\n"
  exit 1   # safe — this branch runs under bash (subprocess), not sourced
fi

# NOTE: No 'set -euo pipefail' here — when sourced, any error would kill
# the parent shell. Errors are handled explicitly via the err() function.

BOLD="\033[1m"; GREEN="\033[1;32m"; CYAN="\033[1;36m"
YELLOW="\033[1;33m"; RED="\033[1;31m"; RESET="\033[0m"

ok()   { printf "  ${GREEN}✔  %s${RESET}\n" "$1"; }
info() { printf "  ${CYAN}▶  %s${RESET}\n" "$1"; }
warn() { printf "  ${YELLOW}⚠  %s${RESET}\n" "$1"; }
# err: print error and return non-zero — never 'exit' when sourced
err()  { printf "  ${RED}✘  FAILED: %s${RESET}\n" "$1"; return 1; }

VAULT_ADDR="${VAULT_ADDR:-https://vault-cluster-3931-public-vault-0d5d4e35.e84a65be.z1.hashicorp.cloud:8200}"
VAULT_NAMESPACE="${VAULT_NAMESPACE:-admin}"
KV_MOUNT="kv"

printf "\n${BOLD}${CYAN}══════════════════════════════════════════════════════${RESET}\n"
printf "${BOLD}  LAB-3931 — Student Environment Setup${RESET}\n"
printf "${BOLD}${CYAN}══════════════════════════════════════════════════════${RESET}\n\n"

# ── Step 0: Preflight checks ──────────────────────────────────
info "Checking prerequisites..."

if [ -z "${VAULT_TOKEN:-}" ]; then
  err "VAULT_TOKEN is not set. Did you forget to source your env file?
  Run:  source scripts/student-tokens/student-sNN.env"
  return 1
fi

if ! command -v vault  >/dev/null 2>&1; then err "vault CLI not found. Install: https://developer.hashicorp.com/vault/downloads"; return 1; fi
if ! command -v packer >/dev/null 2>&1; then err "packer not found. Install: https://developer.hashicorp.com/packer/downloads"; return 1; fi
if ! command -v jq     >/dev/null 2>&1; then err "jq not found. Install: brew install jq"; return 1; fi

ok "vault, packer, jq — all present"
info "Vault address  : ${VAULT_ADDR}"
info "Vault namespace: ${VAULT_NAMESPACE}"
info "Student ID     : ${LAB_STUDENT_ID:-unknown (LAB_STUDENT_ID not set)}"
printf "\n"

# ── Step 1: Verify Vault token is valid and scoped correctly ──
info "Verifying Vault token..."

TOKEN_INFO=$(vault token lookup \
  -address="${VAULT_ADDR}" \
  -namespace="${VAULT_NAMESPACE}" \
  -format=json 2>/dev/null)
if [ $? -ne 0 ] || [ -z "${TOKEN_INFO}" ]; then
  err "Vault token lookup failed. Token may be expired or invalid."
  return 1
fi

TOKEN_DISPLAY=$(echo "${TOKEN_INFO}" | jq -r '.data.display_name // "unknown"')
TOKEN_TTL_LEFT=$(echo "${TOKEN_INFO}" | jq -r '.data.ttl // "unknown"')
TOKEN_POLICIES=$(echo "${TOKEN_INFO}" | jq -r '[.data.policies[]?] | join(", ")')

ok "Token valid — display_name: ${TOKEN_DISPLAY}"
ok "Policies: ${TOKEN_POLICIES}"
ok "TTL remaining: ${TOKEN_TTL_LEFT}s (~$(( ${TOKEN_TTL_LEFT} / 3600 ))h)"
printf "\n"

# ── Step 2: Fetch IBM API key from Vault ──────────────────────
info "Fetching IBM_API_KEY from Vault (mount=${KV_MOUNT}, path=IBM_cloud)..."

IBM_API_KEY_VAL=$(vault kv get \
  -address="${VAULT_ADDR}" \
  -namespace="${VAULT_NAMESPACE}" \
  -mount="${KV_MOUNT}" \
  -field=ibm_api_key \
  IBM_cloud 2>/dev/null)
if [ -z "${IBM_API_KEY_VAL}" ]; then
  err "Could not read IBM_cloud secret. Check your token policy with the instructor."
  return 1
fi

export IBM_API_KEY="${IBM_API_KEY_VAL}"
ok "IBM_API_KEY fetched (${#IBM_API_KEY_VAL} chars)"

# ── Step 3: Fetch HCP credentials from Vault ─────────────────
info "Fetching HCP_CLIENT_ID from Vault (mount=${KV_MOUNT}, path=Packer)..."

HCP_CLIENT_ID_VAL=$(vault kv get \
  -address="${VAULT_ADDR}" \
  -namespace="${VAULT_NAMESPACE}" \
  -mount="${KV_MOUNT}" \
  -field=HCP_CLIENT_ID \
  Packer 2>/dev/null)
if [ -z "${HCP_CLIENT_ID_VAL}" ]; then
  err "Could not read HCP_CLIENT_ID from Vault. Check your token policy with the instructor."
  return 1
fi

export HCP_CLIENT_ID="${HCP_CLIENT_ID_VAL}"
ok "HCP_CLIENT_ID fetched"

info "Fetching HCP_CLIENT_SECRET from Vault..."

HCP_CLIENT_SECRET_VAL=$(vault kv get \
  -address="${VAULT_ADDR}" \
  -namespace="${VAULT_NAMESPACE}" \
  -mount="${KV_MOUNT}" \
  -field=HCP_CLIENT_SECRET \
  Packer 2>/dev/null)
if [ -z "${HCP_CLIENT_SECRET_VAL}" ]; then
  err "Could not read HCP_CLIENT_SECRET from Vault. Check your token policy with the instructor."
  return 1
fi

export HCP_CLIENT_SECRET="${HCP_CLIENT_SECRET_VAL}"
ok "HCP_CLIENT_SECRET fetched"
printf "\n"

# ── Step 3.5: Fetch public key from Vault ─────────────────────────
info "Fetching SSH public key from Vault (mount=${KV_MOUNT}, path=IBM_cloud)..."

IBM_PUBLIC_KEY=$(curl -sk \
  -H "X-Vault-Token: ${VAULT_TOKEN}" \
  -H "X-Vault-Namespace: ${VAULT_NAMESPACE}" \
  "${VAULT_ADDR}/v1/kv/data/IBM_cloud" | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print(d['data']['data']['public_key'])" 2>/dev/null)

if [ -z "${IBM_PUBLIC_KEY}" ]; then
  err "Could not read public_key from Vault kv/IBM_cloud."
  return 1
fi
ok "SSH public key fetched from Vault"

# Resolve path to the matching private key (ships with the repo)
# SCRIPT_DIR is set early here so Step 3.5 can use it before Step 4
# Use BASH_SOURCE[0] when available; fall back to the known absolute path
# so the script works whether sourced from the repo root or elsewhere.
_SRC="${BASH_SOURCE[0]:-${(%):-%x}}"
if [[ "${_SRC}" == /* ]]; then
  SCRIPT_DIR="$(dirname "${_SRC}")"
else
  SCRIPT_DIR="$(cd "$(dirname "${_SRC}")" 2>/dev/null && pwd)"
fi
# Last-resort: walk up from cwd to find ent_demo_ed25519
if [ -z "${SCRIPT_DIR}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
fi
PRIVATE_KEY_FILE="${SCRIPT_DIR}/../../ent_demo_ed25519"
# If the .. traversal doesn't find it, try the workspace root directly
if [ ! -f "${PRIVATE_KEY_FILE}" ]; then
  PRIVATE_KEY_FILE="/Users/fahimshaikh/Desktop/Tf_vault_demo/ent_demo_ed25519"
fi
if [ ! -f "${PRIVATE_KEY_FILE}" ]; then
  err "Private key not found at ${PRIVATE_KEY_FILE}. Check the repo."
  return 1
fi
chmod 600 "${PRIVATE_KEY_FILE}"
ok "Private key found: ${PRIVATE_KEY_FILE}"
printf "\n"

# ── Step 4: Generate student vars file ───────────────────────
# SCRIPT_DIR is already set in Step 3.5 above — do not re-derive it here
PACKER_DIR="${SCRIPT_DIR}/../packer"
VARS_FILE="${PACKER_DIR}/student.pkrvars.hcl"
STUDENT_NUM="${LAB_STUDENT_ID:-student-unknown}"

info "Writing ${VARS_FILE} ..."

# ibm_api_key is written into the vars file as a belt-and-suspenders
# fallback. The variable default in variables.pkr.hcl already reads
# env("IBM_API_KEY"), but writing it here ensures packer validate and
# packer build work correctly even if the env var is not visible
# (e.g. when running packer from a new terminal tab).
cat > "${VARS_FILE}" <<VARS
# ---------------------------------------------------------------
# packer/student.pkrvars.hcl — auto-generated by student-setup-env.sh
# Student: ${STUDENT_NUM}
# Generated: $(date)
# DO NOT commit this file — it is in .gitignore
# ---------------------------------------------------------------

# IBM API key — sourced from Vault at setup time (never hardcoded)
ibm_api_key = "${IBM_API_KEY_VAL}"

# Student identity stamped into /etc/os-release on the golden image
student_id = "${STUDENT_NUM}"

# IBM Cloud resource group (dedicated lab account)
ibm_resource_group_id = "90733208e12b46eda9c4fbc130b8e426"

# us-south build subnet (dedicated lab account)
subnet_id_us_south = "0717-c20d5d2d-6216-4b99-88d7-8b441ef20a9e"

# eu-de build subnet (dedicated lab account)
subnet_id_eu_de = "02b7-df5e6a98-fa9c-4e87-b67c-057d360b62ba"

# Build BOTH regions: us-south (primary) + eu-de (DR)
# Both images are built in parallel and registered in HCP Packer
build_eu_de = true

# Base image
base_image_name = "ibm-redhat-9-8-minimal-amd64-2"

# Image name prefix (timestamp appended automatically)
image_name_prefix = "rhel92-golden"
VARS

chmod 600 "${VARS_FILE}"
ok "student.pkrvars.hcl written"
printf "\n"

# ── Step 5: Verify all env vars are set ──────────────────────
info "Final credential check..."

ALL_OK=true
for VAR in IBM_API_KEY HCP_CLIENT_ID HCP_CLIENT_SECRET; do
  # Use eval for indirect expansion — works in both bash and zsh
  VAL=$(eval echo "\${${VAR}:-}")
  if [ -n "${VAL}" ]; then
    ok "${VAR} set (${#VAL} chars)"
  else
    warn "${VAR} is empty — something went wrong above"
    ALL_OK=false
  fi
done

printf "\n"

if [ "${ALL_OK}" = "true" ]; then
  printf "${BOLD}${GREEN}══════════════════════════════════════════════════════${RESET}\n"
  printf "${BOLD}${GREEN}  ✅  Environment ready! You can now run the build.${RESET}\n"
  printf "${BOLD}${GREEN}══════════════════════════════════════════════════════${RESET}\n\n"

  printf "  Run these commands now:\n\n"
  printf "  ${CYAN}cd packer/${RESET}\n"
  printf "  ${CYAN}packer init .${RESET}\n"
  printf "  ${CYAN}packer validate -var-file=student.pkrvars.hcl .${RESET}\n"
  printf "  ${CYAN}packer build   -var-file=student.pkrvars.hcl .${RESET}\n\n"
  printf "  ${YELLOW}⚠  Keep this terminal open — the build takes ~25 minutes.${RESET}\n\n"
else
  printf "${RED}  Setup incomplete. Fix the errors above before building.${RESET}\n\n"
  return 1
fi
