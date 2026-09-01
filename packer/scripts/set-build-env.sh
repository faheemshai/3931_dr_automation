#!/usr/bin/env bash
# ---------------------------------------------------------------
# packer/scripts/set-build-env.sh
#
# LAB-3931 — Set all environment variables needed for packer build
#
# This script reads every credential from Vault so students never
# have to copy/paste secrets manually or use raw export commands.
#
# HOW TO USE — run ONCE before every packer build:
#
#   source packer/scripts/set-build-env.sh
#
# Note: use "source" (or the dot operator ". "), NOT "bash".
# "source" sets variables in YOUR current shell.
# "bash" runs in a subprocess — variables disappear when it exits.
#
# WHAT THIS SETS:
#   IBM_API_KEY           — IBM Cloud API key (from Vault kv/IBM_cloud)
#   HCP_CLIENT_ID         — HCP service principal ID (from Vault kv/HCP_packer)
#   HCP_CLIENT_SECRET     — HCP service principal secret (from Vault)
#   HCP_ORGANIZATION_ID   — Your HCP org UUID (hardcoded — not a secret)
#   HCP_PROJECT_ID        — Your HCP project UUID (hardcoded — not a secret)
#
# WHY THESE CANNOT GO IN student.pkrvars.hcl:
#   ibm_api_key     → CAN go in .pkrvars.hcl (it's a declared Packer variable)
#   HCP_CLIENT_*    → CANNOT — hcp_packer_registry reads ONLY from env vars,
#                     not from Packer input variables. There is no HCL variable
#                     for HCP credentials. This is by design — HCP auth is
#                     handled at the Packer binary level, not the template level.
# ---------------------------------------------------------------

# Detect if script is being sourced (required) or run directly (wrong)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "ERROR: Run this script with 'source', not 'bash':"
  echo ""
  echo "  source packer/scripts/set-build-env.sh"
  echo ""
  echo "Using 'bash' runs in a subprocess — env vars are lost when it exits."
  exit 1
fi

BOLD="\033[1m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
CYAN="\033[1;36m"
RED="\033[1;31m"
RESET="\033[0m"

echo -e "\n${BOLD}LAB-3931 — Loading build environment from Vault${RESET}"
echo -e "${CYAN}────────────────────────────────────────────────${RESET}"

# ── Vault connection check ────────────────────────────────────────
if ! vault token lookup > /dev/null 2>&1; then
  echo -e "${RED}✘  Not authenticated to Vault. Run:${RESET}"
  echo -e "     vault login -method=userpass username=<your-id>"
  return 1
fi
echo -e "${GREEN}✔  Vault connection OK${RESET}"

# ── IBM Cloud API key ─────────────────────────────────────────────
echo -e "${YELLOW}▶  Reading IBM_API_KEY from kv/IBM_cloud ...${RESET}"
IBM_API_KEY=$(vault kv get -namespace=admin -mount=kv -field=ibm_api_key IBM_cloud 2>/dev/null)
if [ -z "${IBM_API_KEY}" ]; then
  echo -e "${RED}✘  Failed to read ibm_api_key from Vault (kv/IBM_cloud)${RESET}"
  return 1
fi
export IBM_API_KEY
echo -e "${GREEN}✔  IBM_API_KEY set (${#IBM_API_KEY} chars)${RESET}"

# ── HCP Client ID ─────────────────────────────────────────────────
echo -e "${YELLOW}▶  Reading HCP_CLIENT_ID from kv/HCP_packer ...${RESET}"
HCP_CLIENT_ID=$(vault kv get -namespace=admin -mount=kv -field=client_id HCP_packer 2>/dev/null)
if [ -z "${HCP_CLIENT_ID}" ]; then
  echo -e "${RED}✘  Failed to read client_id from Vault (kv/HCP_packer)${RESET}"
  return 1
fi
export HCP_CLIENT_ID
echo -e "${GREEN}✔  HCP_CLIENT_ID set${RESET}"

# ── HCP Client Secret ─────────────────────────────────────────────
echo -e "${YELLOW}▶  Reading HCP_CLIENT_SECRET from kv/HCP_packer ...${RESET}"
HCP_CLIENT_SECRET=$(vault kv get -namespace=admin -mount=kv -field=client_secret HCP_packer 2>/dev/null)
if [ -z "${HCP_CLIENT_SECRET}" ]; then
  echo -e "${RED}✘  Failed to read client_secret from Vault (kv/HCP_packer)${RESET}"
  return 1
fi
export HCP_CLIENT_SECRET
echo -e "${GREEN}✔  HCP_CLIENT_SECRET set (${#HCP_CLIENT_SECRET} chars)${RESET}"

# ── HCP Org + Project IDs ─────────────────────────────────────────
# These are not secrets — they are identifiers visible in the portal URL.
# Lab instructor pre-fills these. Students do not need to change them.
export HCP_ORGANIZATION_ID="d964990b-39d2-42d2-b37b-bb8ce075c701"
export HCP_PROJECT_ID="48e86032-f0da-45af-a68d-67c67d1f383b"
echo -e "${GREEN}✔  HCP_ORGANIZATION_ID set${RESET}"
echo -e "${GREEN}✔  HCP_PROJECT_ID set${RESET}"

echo -e "${CYAN}────────────────────────────────────────────────${RESET}"
echo -e "${GREEN}${BOLD}✔  All environment variables loaded. Ready to build.${RESET}"
echo ""
echo -e "  ${BOLD}Next step:${RESET}"
echo -e "  ${CYAN}cd packer/${RESET}"
echo -e "  ${CYAN}packer build -var-file=student.pkrvars.hcl .${RESET}"
echo ""
