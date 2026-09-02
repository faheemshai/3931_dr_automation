#!/bin/bash
# ---------------------------------------------------------------
# scripts/instructor-revoke-student-tokens.sh
#
# Run this AFTER the lab ends to immediately revoke all 15
# student tokens. Tokens cannot be used after revocation.
#
# Usage:
#   export VAULT_ADDR="https://vault-cluster-..."
#   export VAULT_NAMESPACE="admin"
#   export VAULT_TOKEN="<your-admin-token>"
#   bash scripts/instructor-revoke-student-tokens.sh
# ---------------------------------------------------------------

set -euo pipefail

GREEN="\033[1;32m"; CYAN="\033[1;36m"; RED="\033[1;31m"; RESET="\033[0m"
ok()  { printf "  ${GREEN}✔  %s${RESET}\n" "$1"; }
info(){ printf "  ${CYAN}▶  %s${RESET}\n" "$1"; }
err() { printf "  ${RED}✘  %s${RESET}\n" "$1"; }

VAULT_ADDR="${VAULT_ADDR:-https://vault-cluster-public-vault-564045ad.ea599dfb.z1.hashicorp.cloud:8200}"
VAULT_NAMESPACE="${VAULT_NAMESPACE:-admin}"
TOKEN_DIR="student-tokens"

[ -z "${VAULT_TOKEN:-}" ] && { err "VAULT_TOKEN not set"; exit 1; }

info "Revoking all student tokens..."
printf "\n"

for ENV_FILE in "${TOKEN_DIR}"/student-s*.env; do
  [ -f "${ENV_FILE}" ] || continue
  STUDENT_TOKEN=$(grep 'export VAULT_TOKEN=' "${ENV_FILE}" | cut -d'"' -f2)
  STUDENT_ID=$(basename "${ENV_FILE}" .env)

  if [ -n "${STUDENT_TOKEN}" ]; then
    vault token revoke \
      -address="${VAULT_ADDR}" \
      -namespace="${VAULT_NAMESPACE}" \
      "${STUDENT_TOKEN}" > /dev/null 2>&1 && ok "${STUDENT_ID}: revoked" || err "${STUDENT_ID}: revoke failed (already expired?)"
  fi
done

printf "\n"
ok "All student tokens revoked. Lab cleanup complete."
rm -rf "${TOKEN_DIR}"
ok "student-tokens/ directory removed."
