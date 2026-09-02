#!/bin/sh
# ---------------------------------------------------------------
# scripts/hcp-backfill-registration.sh
#
# ONE-TIME BACKFILL: Registers both golden image artifacts from the
# most recent packer-manifest.json into HCP Packer.
#
# Run this AFTER creating the 'rhel92-golden' bucket in the HCP portal:
#   https://portal.cloud.hashicorp.com/orgs/d964990b-39d2-42d2-b37b-bb8ce075c701/projects/48e86032-f0da-45af-a68d-67c67d1f383b/packer
#
# Prerequisites:
#   source scripts/student-tokens/student-s1.env
#   source scripts/student-setup-env.sh      # sets HCP_CLIENT_ID/SECRET
#
# Usage:
#   sh scripts/hcp-backfill-registration.sh
# ---------------------------------------------------------------

set -e

BOLD="\033[1m"; GREEN="\033[1;32m"; CYAN="\033[1;36m"
YELLOW="\033[1;33m"; RED="\033[1;31m"; RESET="\033[0m"

ok()   { printf "  ${GREEN}✔  %s${RESET}\n" "$1"; }
info() { printf "  ${CYAN}▶  %s${RESET}\n"  "$1"; }
warn() { printf "  ${YELLOW}⚠  %s${RESET}\n" "$1"; }
err()  { printf "  ${RED}✘  %s${RESET}\n"  "$1"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKER_DIR="${SCRIPT_DIR}/../packer"
MANIFEST="${PACKER_DIR}/packer-manifest.json"

printf "\n${BOLD}${CYAN}══════════════════════════════════════════════════════${RESET}\n"
printf "${BOLD}  HCP Packer — Backfill both-region registration${RESET}\n"
printf "${BOLD}${CYAN}══════════════════════════════════════════════════════${RESET}\n\n"

# ── Preflight ─────────────────────────────────────────────────
[ -z "${HCP_CLIENT_ID:-}"     ] && err "HCP_CLIENT_ID not set. Run: source scripts/student-setup-env.sh"
[ -z "${HCP_CLIENT_SECRET:-}" ] && err "HCP_CLIENT_SECRET not set. Run: source scripts/student-setup-env.sh"
[ -f "${MANIFEST}" ]             || err "packer-manifest.json not found at ${MANIFEST}"

command -v jq  >/dev/null 2>&1 || err "jq not found"
command -v curl >/dev/null 2>&1 || err "curl not found"

# ── Constants ─────────────────────────────────────────────────
HCP_API="https://api.cloud.hashicorp.com/packer/2023-01-01"
ORG="d964990b-39d2-42d2-b37b-bb8ce075c701"
PROJ="48e86032-f0da-45af-a68d-67c67d1f383b"
BUCKET="rhel92-golden"

# ── Read latest run artifacts from manifest ───────────────────
LAST_UUID=$(jq -r '.last_run_uuid' "${MANIFEST}")
info "Last build run UUID: ${LAST_UUID}"

US_SOUTH_ID=$(jq -r --arg uuid "${LAST_UUID}" \
  '.builds[] | select(.packer_run_uuid == $uuid and (.name | contains("us_south"))) | .artifact_id' \
  "${MANIFEST}" | head -1)
EU_DE_ID=$(jq -r --arg uuid "${LAST_UUID}" \
  '.builds[] | select(.packer_run_uuid == $uuid and (.name | contains("eu_de"))) | .artifact_id' \
  "${MANIFEST}" | head -1)
BUILD_TIME=$(jq -r --arg uuid "${LAST_UUID}" \
  '.builds[] | select(.packer_run_uuid == $uuid) | .build_time' \
  "${MANIFEST}" | head -1)

info "us-south artifact: ${US_SOUTH_ID}"
info "eu-de    artifact: ${EU_DE_ID}"

[ -z "${US_SOUTH_ID}" ] && err "us-south artifact_id not found in manifest"
[ -z "${EU_DE_ID}"    ] && err "eu-de artifact_id not found in manifest"

BUILD_DATE=$(date -r "${BUILD_TIME}" "+%Y-%m-%d" 2>/dev/null || \
             date -d "@${BUILD_TIME}" "+%Y-%m-%d" 2>/dev/null || \
             date "+%Y-%m-%d")
# Derive fingerprint from build_time (matches the fp-TIMESTAMP pattern used in the build)
FINGERPRINT="fp-$(date -r "${BUILD_TIME}" "+%Y%m%d%H%M%S" 2>/dev/null || \
                  date -d "@${BUILD_TIME}" "+%Y%m%d%H%M%S" 2>/dev/null || \
                  date "+%Y%m%d%H%M%S")"
info "Fingerprint: ${FINGERPRINT}"
printf "\n"

# ── Get HCP token ─────────────────────────────────────────────
info "Authenticating to HCP..."
TOKEN_RESP=$(curl -s --max-time 30 \
  --request POST \
  --url "https://auth.idp.hashicorp.com/oauth2/token" \
  --header "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "grant_type=client_credentials" \
  --data-urlencode "client_id=${HCP_CLIENT_ID}" \
  --data-urlencode "client_secret=${HCP_CLIENT_SECRET}" \
  --data-urlencode "audience=https://api.hashicorp.cloud")
HCP_TOKEN=$(printf '%s' "${TOKEN_RESP}" | jq -r '.access_token // empty')
[ -z "${HCP_TOKEN}" ] && err "HCP token fetch failed: ${TOKEN_RESP}"
ok "HCP token obtained"

_hcp() {
  curl -s --max-time 30 \
    -H "Authorization: Bearer ${HCP_TOKEN}" \
    -H "Content-Type: application/json" "$@"
}

# ── Verify bucket exists ──────────────────────────────────────
info "Verifying bucket '${BUCKET}' exists..."
BUCKET_RESP=$(_hcp "${HCP_API}/organizations/${ORG}/projects/${PROJ}/buckets/${BUCKET}")
BUCKET_OK=$(printf '%s' "${BUCKET_RESP}" | jq -r '.bucket.slug // .bucket.name // .bucket.id // empty')
if [ -z "${BUCKET_OK}" ]; then
  err "Bucket '${BUCKET}' not found. Create it first:
  → https://portal.cloud.hashicorp.com/orgs/${ORG}/projects/${PROJ}/packer
    Click 'Create Bucket' → name: ${BUCKET}"
fi
ok "Bucket found: ${BUCKET}"

# ── Create version (shared fingerprint) ──────────────────────
info "Creating version (fingerprint=${FINGERPRINT})..."
VER_RESP=$(_hcp --request POST \
  "${HCP_API}/organizations/${ORG}/projects/${PROJ}/buckets/${BUCKET}/versions" \
  --data "{\"fingerprint\":\"${FINGERPRINT}\",\"template_type\":\"HCL2\"}")
VERSION_ID=$(printf '%s' "${VER_RESP}" | jq -r '.version.id // empty')

# If version already exists (idempotent re-run), look it up
if [ -z "${VERSION_ID}" ]; then
  VERSIONS_RESP=$(_hcp "${HCP_API}/organizations/${ORG}/projects/${PROJ}/buckets/${BUCKET}/versions")
  VERSION_ID=$(printf '%s' "${VERSIONS_RESP}" | jq -r \
    ".versions[]? | select(.fingerprint==\"${FINGERPRINT}\") | .id" | head -1)
fi
[ -z "${VERSION_ID}" ] && err "Version create/lookup failed: ${VER_RESP}"
ok "Version: ${VERSION_ID}"

# ── Register each region as a separate build record ──────────
register_artifact() {
  REGION="$1"; ART_ID="$2"; BUILD_NAME="$3"
  info "Registering ${REGION} artifact (${ART_ID})..."
  PAYLOAD=$(jq -n \
    --arg comp   "${BUILD_NAME}" \
    --arg uuid   "${LAST_UUID}" \
    --arg date   "${BUILD_DATE}" \
    --arg region "${REGION}" \
    --arg art_id "${ART_ID}" \
    '{
      component_type:  $comp,
      packer_run_uuid: $uuid,
      status:          "BUILD_DONE",
      platform:        "ibmcloud",
      labels: {
        "build-date":     $date,
        "region":         $region,
        "pipeline-stage": "golden-image",
        "cis-benchmark":  "rhel9-level-1"
      },
      artifacts: [{"external_identifier": $art_id, "region": $region}]
    }')
  BUILD_RESP=$(_hcp --request POST \
    "${HCP_API}/organizations/${ORG}/projects/${PROJ}/buckets/${BUCKET}/versions/${FINGERPRINT}/builds" \
    --data "${PAYLOAD}")
  BUILD_ID=$(printf '%s' "${BUILD_RESP}" | jq -r '.build.id // empty')
  if [ -z "${BUILD_ID}" ]; then
    warn "${REGION} build record failed: $(printf '%s' "${BUILD_RESP}" | head -c 300)"
  else
    ok "${REGION} build record: ${BUILD_ID}"
  fi
}

register_artifact "us-south" "${US_SOUTH_ID}" "rhel92_us_south"
register_artifact "eu-de"    "${EU_DE_ID}"    "rhel92_eu_de"

# ── Mark version complete ─────────────────────────────────────
info "Marking version complete..."
_hcp --request PATCH \
  "${HCP_API}/organizations/${ORG}/projects/${PROJ}/buckets/${BUCKET}/versions/${FINGERPRINT}" \
  --data '{}' > /dev/null
ok "Version marked complete"

printf "\n${GREEN}${BOLD}══════════════════════════════════════════════════════${RESET}\n"
printf "${GREEN}${BOLD}  ✅  HCP Packer registration complete!${RESET}\n"
printf "${GREEN}${BOLD}══════════════════════════════════════════════════════${RESET}\n\n"
printf "  %-22s %s\n" "Bucket:"      "${BUCKET}"
printf "  %-22s %s\n" "Fingerprint:" "${FINGERPRINT}"
printf "  %-22s %s\n" "Version ID:"  "${VERSION_ID}"
printf "  %-22s %s\n" "us-south ID:" "${US_SOUTH_ID}"
printf "  %-22s %s\n" "eu-de ID:"    "${EU_DE_ID}"
printf "  %-22s https://portal.cloud.hashicorp.com/orgs/${ORG}/projects/${PROJ}/packer/buckets/${BUCKET}\n" "Portal:"
printf "\n"
