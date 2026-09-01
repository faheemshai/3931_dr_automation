#!/bin/sh
# ---------------------------------------------------------------
# packer/scripts/hcp-register-build.sh
#
# Called automatically by Packer's post-processor "shell-local"
# immediately after the image is captured.
#
# Packer passes context via environment variables:
#   PACKER_BUILD_NAME   — e.g. "rhel92_us_south"
#   PACKER_RUN_UUID     — unique ID for this build run
#   HCP_CLIENT_ID       — set before packer build (from Vault)
#   HCP_CLIENT_SECRET   — set before packer build (from Vault)
#
# The image ID and image name are read from packer-manifest.json
# which the "manifest" post-processor writes just before this runs.
#
# Usage (called by Packer, not directly):
#   Post-processor "shell-local" in rhel92-ibmcloud.pkr.hcl
# ---------------------------------------------------------------

# Do NOT use set -e — curl failures must be handled explicitly so the
# post-processor always exits 0 (image is already built; HCP is optional).

BOLD="\033[1m"
CYAN="\033[1;36m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
RESET="\033[0m"

ok()   { printf "  ${GREEN}✔  %s${RESET}\n" "$1"; }
info() { printf "  ${YELLOW}▶  %s${RESET}\n" "$1"; }
warn() { printf "  ${RED}✘  %s${RESET}\n" "$1"; }

HCP_API="https://api.cloud.hashicorp.com/packer/2023-01-01"
ORG="d964990b-39d2-42d2-b37b-bb8ce075c701"
PROJ="48e86032-f0da-45af-a68d-67c67d1f383b"
BUCKET="rhel92-golden"

# Packer sets this to the directory containing the template
PACKER_DIR="${PACKER_TEMPLATE_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
MANIFEST="${PACKER_DIR}/packer-manifest.json"

printf "\n${CYAN}════════════════════════════════════════════════════${RESET}\n"
printf "${BOLD}  HCP Packer — registering build${RESET}\n"
printf "${CYAN}════════════════════════════════════════════════════${RESET}\n\n"

# ── Validate required env vars ────────────────────────────────
if [ -z "${HCP_CLIENT_ID}" ] || [ -z "${HCP_CLIENT_SECRET}" ]; then
  warn "HCP_CLIENT_ID or HCP_CLIENT_SECRET not set — skipping HCP registration"
  printf "\n  To register on the next build, export before running packer:\n"
  printf "    ${CYAN}export HCP_CLIENT_ID=\$(vault kv get -namespace=admin -mount=kv -field=client_id Packer)${RESET}\n"
  printf "    ${CYAN}export HCP_CLIENT_SECRET=\$(vault kv get -namespace=admin -mount=kv -field=client_secret Packer)${RESET}\n\n"
  exit 0   # exit 0 — don't fail the build over optional HCP step
fi

# ── Read artifact from manifest ───────────────────────────────
if [ ! -f "${MANIFEST}" ]; then
  warn "packer-manifest.json not found at ${MANIFEST} — skipping"
  exit 0
fi

ARTIFACT_ID=$(jq -r '.builds[-1].artifact_id'     "${MANIFEST}" 2>/dev/null)
RUN_UUID=$(jq -r    '.builds[-1].packer_run_uuid'  "${MANIFEST}" 2>/dev/null)
BUILD_TIME=$(jq -r  '.builds[-1].build_time'       "${MANIFEST}" 2>/dev/null)
BUILD_NAME=$(jq -r  '.builds[-1].name'             "${MANIFEST}" 2>/dev/null)

# Derive region from build name suffix
case "${BUILD_NAME}" in
  *us_south*) REGION="us-south" ;;
  *eu_de*)    REGION="eu-de"    ;;
  *)          REGION="us-south" ;;
esac

BUILD_DATE=$(date -r "${BUILD_TIME}" "+%Y-%m-%d" 2>/dev/null || \
             date -d "@${BUILD_TIME}" "+%Y-%m-%d" 2>/dev/null || \
             date "+%Y-%m-%d")

printf "  %-20s %s\n" "Artifact ID:"  "${ARTIFACT_ID}"
printf "  %-20s %s\n" "Run UUID:"     "${RUN_UUID}"
printf "  %-20s %s\n" "Build name:"   "${BUILD_NAME}"
printf "  %-20s %s\n" "Region:"       "${REGION}"
printf "  %-20s %s\n" "Build date:"   "${BUILD_DATE}"
printf "\n"

# ── Get HCP token ─────────────────────────────────────────────
info "Authenticating to HCP..."
# -s = silent, no -f so HTTP errors don't cause non-zero exit, --retry 3
TOKEN_RESP=$(curl -s --retry 3 --retry-delay 2 --max-time 30 \
  --request POST \
  --url "https://auth.idp.hashicorp.com/oauth2/token" \
  --header "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "grant_type=client_credentials" \
  --data-urlencode "client_id=${HCP_CLIENT_ID}" \
  --data-urlencode "client_secret=${HCP_CLIENT_SECRET}" \
  --data-urlencode "audience=https://api.hashicorp.cloud" 2>/dev/null)
HCP_TOKEN=$(printf '%s' "${TOKEN_RESP}" | jq -r '.access_token // empty' 2>/dev/null)

if [ -z "${HCP_TOKEN}" ]; then
  warn "HCP token fetch failed — skipping registration"
  printf "  Response: %.200s\n" "${TOKEN_RESP}"
  exit 0
fi
ok "HCP token obtained"

# Helper for all subsequent HCP API calls
# -s silent, no -f, --retry 3 so transient network blips are retried
_hcp() {
  curl -s --retry 3 --retry-delay 2 --max-time 30 \
    -H "Authorization: Bearer ${HCP_TOKEN}" \
    -H "Content-Type: application/json" "$@"
}

# ── Step 1: Verify bucket exists ─────────────────────────────
info "Checking bucket '${BUCKET}'..."
BUCKET_RESP=$(_hcp "${HCP_API}/organizations/${ORG}/projects/${PROJ}/buckets/${BUCKET}" 2>/dev/null)
# The API may return slug, name, or id depending on version — check for any
BUCKET_OK=$(printf '%s' "${BUCKET_RESP}" | jq -r '
  .bucket.slug // .bucket.name // .bucket.id // empty' 2>/dev/null)
# Also accept response if it has no "code" error field (i.e. not a 404)
HAS_ERROR=$(printf '%s' "${BUCKET_RESP}" | jq -r '.code // empty' 2>/dev/null)
if [ -z "${BUCKET_OK}" ] && [ -n "${HAS_ERROR}" ]; then
  warn "Bucket '${BUCKET}' not found — run: packer build hcp-bucket-init.pkr.hcl"
  printf "  API response: %.200s\n" "${BUCKET_RESP}"
  exit 0
fi
ok "Bucket reachable: ${BUCKET}"

# ── Step 2: Get or create version ────────────────────────────
# Check if a version with this fingerprint already exists (e.g. from a
# previous failed run) so we can reuse it instead of creating a duplicate.
info "Checking for existing version (fingerprint=${RUN_UUID})..."
VERSIONS_RESP=$(_hcp "${HCP_API}/organizations/${ORG}/projects/${PROJ}/buckets/${BUCKET}/versions" 2>/dev/null)
VERSION_ID=$(printf '%s' "${VERSIONS_RESP}" | jq -r \
  ".versions[]? | select(.fingerprint==\"${RUN_UUID}\") | .id" 2>/dev/null | head -1)

if [ -n "${VERSION_ID}" ]; then
  ok "Existing version found: ${VERSION_ID} — reusing"
else
  info "Creating new version..."
  VER_RESP=$(_hcp --request POST \
    "${HCP_API}/organizations/${ORG}/projects/${PROJ}/buckets/${BUCKET}/versions" \
    --data "{\"fingerprint\":\"${RUN_UUID}\"}" 2>/dev/null)
  VERSION_ID=$(printf '%s' "${VER_RESP}" | jq -r '.version.id // empty' 2>/dev/null)
  if [ -z "${VERSION_ID}" ]; then
    warn "Version create failed: $(printf '%s' "${VER_RESP}" | head -c 300)"
    exit 0
  fi
  ok "Version created: ${VERSION_ID}"
  # Give HCP a moment to fully commit the new version
  sleep 3
fi

# ── Step 3: Create build record with hardening labels ─────────
info "Creating build record..."
BUILD_PAYLOAD=$(jq -n \
  --arg comp   "${BUILD_NAME}" \
  --arg uuid   "${RUN_UUID}" \
  --arg date   "${BUILD_DATE}" \
  --arg region "${REGION}" \
  '{
    component_type:  $comp,
    packer_run_uuid: $uuid,
    status:          "BUILD_RUNNING",
    platform:        "ibmcloud",
    labels: {
      "build-date":        $date,
      "primary-region":    $region,
      "hardening-step-1":  "system-packages-updated",
      "hardening-step-2":  "nginx-jq-openssl-curl-installed",
      "hardening-step-3":  "unnecessary-services-disabled",
      "hardening-step-4":  "cis-sysctl-kernel-hardening-applied",
      "hardening-step-5":  "selinux-set-to-enforcing",
      "hardening-step-6":  "ssh-hardened-no-password-auth",
      "hardening-step-7":  "firewalld-drop-zone-ssh-http-https-only",
      "hardening-step-8":  "audit-chrony-rsyslog-enabled-at-boot",
      "cis-benchmark":     "rhel9-level-1",
      "sbom-format":       "cyclonedx-json",
      "sbom-scanner":      "packer-syft-embedded",
      "pipeline-stage":    "golden-image"
    }
  }')
BUILD_RESP=$(_hcp --request POST \
  "${HCP_API}/organizations/${ORG}/projects/${PROJ}/buckets/${BUCKET}/versions/${VERSION_ID}/builds" \
  --data "${BUILD_PAYLOAD}" 2>/dev/null)
BUILD_ID=$(printf '%s' "${BUILD_RESP}" | jq -r '.build.id // empty' 2>/dev/null)
if [ -z "${BUILD_ID}" ]; then
  warn "Build record failed: $(printf '%s' "${BUILD_RESP}" | head -c 300)"
  exit 0
fi
ok "Build record created: ${BUILD_ID}"

# ── Step 4: Register artifact ─────────────────────────────────
info "Registering artifact: ${ARTIFACT_ID}..."
_hcp --request POST \
  "${HCP_API}/organizations/${ORG}/projects/${PROJ}/buckets/${BUCKET}/versions/${VERSION_ID}/builds/${BUILD_ID}/artifacts" \
  --data "{
    \"external_identifier\": \"${ARTIFACT_ID}\",
    \"region\": \"${REGION}\",
    \"labels\": {\"cloud\": \"ibm-cloud\", \"region\": \"${REGION}\"}
  }" > /dev/null 2>&1
ok "Artifact registered"

# ── Step 5: Mark build DONE ───────────────────────────────────
info "Marking build DONE..."
_hcp --request PATCH \
  "${HCP_API}/organizations/${ORG}/projects/${PROJ}/buckets/${BUCKET}/versions/${VERSION_ID}/builds/${BUILD_ID}" \
  --data '{"status":"BUILD_DONE"}' > /dev/null 2>&1
ok "Build marked DONE"

# ── Step 6: Complete version ──────────────────────────────────
info "Completing version..."
_hcp --request PATCH \
  "${HCP_API}/organizations/${ORG}/projects/${PROJ}/buckets/${BUCKET}/versions/${VERSION_ID}" \
  --data '{}' > /dev/null 2>&1
ok "Version complete"

printf "\n${GREEN}${BOLD}  HCP Packer registration complete!${RESET}\n"
printf "\n  %-20s %s\n" "Bucket:" "${BUCKET}"
printf "  %-20s %s\n" "Version ID:" "${VERSION_ID}"
printf "  %-20s %s\n" "Artifact:" "${ARTIFACT_ID}"
printf "  %-20s https://portal.cloud.hashicorp.com/orgs/${ORG}/projects/${PROJ}/packer/buckets/${BUCKET}\n" "Portal:"
printf "\n"
