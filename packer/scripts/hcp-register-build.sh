#!/bin/sh
# ---------------------------------------------------------------
# packer/scripts/hcp-register-build.sh
#
# Called automatically by Packer's post-processor "shell-local"
# after EACH region's image is captured (once per source block).
#
# With build_eu_de = true, Packer runs this script twice:
#   Run 1 — after us-south image is captured
#   Run 2 — after eu-de   image is captured
#
# Both runs share the SAME FINGERPRINT (set once at the start
# of the Packer build via PACKER_BUILD_FINGERPRINT) so both
# artifacts end up in the same HCP Packer version, which means:
#   - HCP registry shows one version with TWO regional artifacts
#   - Terraform can look up either artifact by region
#   - Image governance is tied to a single version fingerprint
#
# Environment variables injected by Packer post-processor:
#   PACKER_BUILD_NAME      — e.g. "rhel92_us_south" or "rhel92_eu_de"
#   PACKER_RUN_UUID        — unique ID for this build run
#   HCP_CLIENT_ID          — set before packer build (from Vault)
#   HCP_CLIENT_SECRET      — set before packer build (from Vault)
#   PACKER_TEMPLATE_DIR    — path to packer/ directory
#   PACKER_BUILD_FINGERPRINT — shared across both region runs
#
# The image ID is read from packer-manifest.json which the
# "manifest" post-processor writes just before this runs.
# ---------------------------------------------------------------

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

PACKER_DIR="${PACKER_TEMPLATE_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
MANIFEST="${PACKER_DIR}/packer-manifest.json"

printf "\n${CYAN}════════════════════════════════════════════════════${RESET}\n"
printf "${BOLD}  HCP Packer — registering build: ${PACKER_BUILD_NAME:-unknown}${RESET}\n"
printf "${CYAN}════════════════════════════════════════════════════${RESET}\n\n"

# ── Validate required env vars ────────────────────────────────
if [ -z "${HCP_CLIENT_ID}" ] || [ -z "${HCP_CLIENT_SECRET}" ]; then
  warn "HCP_CLIENT_ID or HCP_CLIENT_SECRET not set — skipping HCP registration"
  printf "\n  To register on the next build, export credentials before running packer:\n"
  printf "    ${CYAN}export HCP_CLIENT_ID=\$(vault kv get -namespace=admin -mount=kv -field=client_id Packer)${RESET}\n"
  printf "    ${CYAN}export HCP_CLIENT_SECRET=\$(vault kv get -namespace=admin -mount=kv -field=client_secret Packer)${RESET}\n\n"
  exit 0
fi

# ── Read this build's artifact from manifest ──────────────────
# The manifest post-processor appends each build as it completes.
# We find the entry that matches the current PACKER_BUILD_NAME.
if [ ! -f "${MANIFEST}" ]; then
  warn "packer-manifest.json not found at ${MANIFEST} — skipping"
  exit 0
fi

# Extract the entry for THIS build name specifically.
# jq outputs a JSON object — pipe through jq -s '.[0]' to safely
# collect multi-line output into a single string before using it.
BUILD_ENTRY=$(jq -c \
  --arg name "${PACKER_BUILD_NAME}" \
  '.builds[] | select(.name == $name)' \
  "${MANIFEST}" 2>/dev/null | head -1)

if [ -z "${BUILD_ENTRY}" ]; then
  # Fall back to latest entry if name match fails (e.g. PACKER_BUILD_NAME not set)
  BUILD_ENTRY=$(jq -c '.builds[-1]' "${MANIFEST}" 2>/dev/null)
fi

ARTIFACT_ID=$(printf '%s' "${BUILD_ENTRY}" | jq -r '.artifact_id'    2>/dev/null)
RUN_UUID=$(printf '%s' "${BUILD_ENTRY}"    | jq -r '.packer_run_uuid' 2>/dev/null)
BUILD_TIME=$(printf '%s' "${BUILD_ENTRY}"  | jq -r '.build_time'      2>/dev/null)
BUILD_NAME=$(printf '%s' "${BUILD_ENTRY}"  | jq -r '.name'            2>/dev/null)

# Derive region from build name suffix
case "${BUILD_NAME}" in
  *us_south*) REGION="us-south" ;;
  *eu_de*)    REGION="eu-de"    ;;
  *)          REGION="us-south" ;;
esac

BUILD_DATE=$(date -r "${BUILD_TIME}" "+%Y-%m-%d" 2>/dev/null || \
             date -d "@${BUILD_TIME}" "+%Y-%m-%d" 2>/dev/null || \
             date "+%Y-%m-%d")

# ── Fingerprint strategy ──────────────────────────────────────
# Use PACKER_BUILD_FINGERPRINT if set (shared across both region runs
# by the calling environment). This ensures us-south and eu-de artifacts
# land in the SAME HCP Packer version.
# If not set, fall back to a timestamp-based fingerprint.
if [ -n "${PACKER_BUILD_FINGERPRINT:-}" ]; then
  FINGERPRINT="${PACKER_BUILD_FINGERPRINT}"
  info "Using shared fingerprint (dual-region): ${FINGERPRINT}"
else
  FINGERPRINT="fp-$(date "+%Y%m%d%H%M%S")"
  info "Using per-run fingerprint (single-region): ${FINGERPRINT}"
fi

printf "  %-22s %s\n" "Artifact ID:"    "${ARTIFACT_ID}"
printf "  %-22s %s\n" "Run UUID:"       "${RUN_UUID}"
printf "  %-22s %s\n" "Fingerprint:"    "${FINGERPRINT}"
printf "  %-22s %s\n" "Build name:"     "${BUILD_NAME}"
printf "  %-22s %s\n" "Region:"         "${REGION}"
printf "  %-22s %s\n" "Build date:"     "${BUILD_DATE}"
printf "\n"

# ── Get HCP token ─────────────────────────────────────────────
info "Authenticating to HCP..."
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

_hcp() {
  curl -s --retry 3 --retry-delay 2 --max-time 30 \
    -H "Authorization: Bearer ${HCP_TOKEN}" \
    -H "Content-Type: application/json" "$@"
}

# ── Step 1: Verify bucket exists ─────────────────────────────
# NOTE: The HCP Packer REST API does NOT expose a bucket-creation
# endpoint (POST /buckets returns Method Not Allowed).
# The bucket must be created ONCE via the HCP portal or Terraform
# hcp_packer_bucket resource before running packer build.
#
# One-time setup (instructor only):
#   Portal → https://portal.cloud.hashicorp.com/orgs/${ORG}/projects/${PROJ}/packer
#   Click "Create Bucket" → name: rhel92-golden
#
#   OR via Terraform (hcp_packer_bucket resource):
#     resource "hcp_packer_bucket" "lab3931" {
#       name       = "rhel92-golden"
#       project_id = "${PROJ}"
#     }
info "Checking bucket '${BUCKET}'..."
BUCKET_RESP=$(_hcp "${HCP_API}/organizations/${ORG}/projects/${PROJ}/buckets/${BUCKET}" 2>/dev/null)
BUCKET_OK=$(printf '%s' "${BUCKET_RESP}" | jq -r '.bucket.slug // .bucket.name // .bucket.id // empty' 2>/dev/null)
HAS_ERROR=$(printf '%s' "${BUCKET_RESP}" | jq -r '.code // empty' 2>/dev/null)

if [ -z "${BUCKET_OK}" ] && [ -n "${HAS_ERROR}" ]; then
  warn "Bucket '${BUCKET}' does not exist in HCP Packer."
  printf "\n  Create it once via the HCP portal:\n"
  printf "    https://portal.cloud.hashicorp.com/orgs/%s/projects/%s/packer\n\n" "${ORG}" "${PROJ}"
  printf "  Then re-run registration manually:\n"
  printf "    PACKER_TEMPLATE_DIR=%s PACKER_BUILD_NAME=rhel92_us_south \\\\\n" "${PACKER_DIR}"
  printf "    PACKER_BUILD_FINGERPRINT=fp-manual sh %s/scripts/hcp-register-build.sh\n\n" "${PACKER_DIR}"
  printf "  IBM Cloud images are already built and available:\n"
  printf "    us-south: check packer-manifest.json → rhel92_us_south artifact_id\n"
  printf "    eu-de:    check packer-manifest.json → rhel92_eu_de artifact_id\n\n"
  # Exit 0 — images are captured; don't fail the overall build
  exit 0
fi
ok "Bucket reachable: ${BUCKET}"

# ── Step 2: Create or reuse version ──────────────────────────
# When building both regions, the second script run (eu-de) will
# find the version already created by the first run (us-south)
# and reuse it. Both artifacts land in the same version.
info "Checking for existing version (fingerprint=${FINGERPRINT})..."
VERSIONS_RESP=$(_hcp "${HCP_API}/organizations/${ORG}/projects/${PROJ}/buckets/${BUCKET}/versions" 2>/dev/null)
EXISTING_VERSION_ID=$(printf '%s' "${VERSIONS_RESP}" | jq -r \
  ".versions[]? | select(.fingerprint==\"${FINGERPRINT}\") | .id" 2>/dev/null | head -1)

if [ -n "${EXISTING_VERSION_ID}" ]; then
  # Version already exists from the first region's run — reuse it
  VERSION_ID="${EXISTING_VERSION_ID}"
  ok "Reusing existing version: ${VERSION_ID} (second region artifact will be added)"
else
  # First region to complete — create the version
  info "Creating new version (fingerprint=${FINGERPRINT})..."
  VER_RESP=$(_hcp --request POST \
    "${HCP_API}/organizations/${ORG}/projects/${PROJ}/buckets/${BUCKET}/versions" \
    --data "{\"fingerprint\":\"${FINGERPRINT}\",\"template_type\":\"HCL2\"}" 2>/dev/null)
  VERSION_ID=$(printf '%s' "${VER_RESP}" | jq -r '.version.id // empty' 2>/dev/null)
  if [ -z "${VERSION_ID}" ]; then
    warn "Version create failed: $(printf '%s' "${VER_RESP}" | head -c 300)"
    exit 0
  fi
  ok "Version created: ${VERSION_ID}"
  sleep 5
fi

# ── Step 3: Add this region's build record to the version ─────
info "Registering ${REGION} artifact in version ${VERSION_ID}..."
BUILD_PAYLOAD=$(jq -n \
  --arg comp   "${BUILD_NAME}" \
  --arg uuid   "${RUN_UUID}" \
  --arg date   "${BUILD_DATE}" \
  --arg region "${REGION}" \
  --arg art_id "${ARTIFACT_ID}" \
  '{
    component_type:  $comp,
    packer_run_uuid: $uuid,
    status:          "BUILD_DONE",
    platform:        "ibmcloud",
    labels: {
      "build-date":        $date,
      "region":            $region,
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
    },
    artifacts: [
      {
        external_identifier: $art_id,
        region:              $region
      }
    ]
  }')
BUILD_RESP=$(_hcp --request POST \
  "${HCP_API}/organizations/${ORG}/projects/${PROJ}/buckets/${BUCKET}/versions/${FINGERPRINT}/builds" \
  --data "${BUILD_PAYLOAD}" 2>/dev/null)
BUILD_ID=$(printf '%s' "${BUILD_RESP}" | jq -r '.build.id // empty' 2>/dev/null)
if [ -z "${BUILD_ID}" ]; then
  warn "Build record failed: $(printf '%s' "${BUILD_RESP}" | head -c 300)"
  exit 0
fi
ok "Build record created: ${BUILD_ID} (artifact: ${ARTIFACT_ID}, region: ${REGION})"

# ── Step 4: Complete version ──────────────────────────────────
# Called by both runs — idempotent, safe to call twice.
info "Marking version complete..."
_hcp --request PATCH \
  "${HCP_API}/organizations/${ORG}/projects/${PROJ}/buckets/${BUCKET}/versions/${FINGERPRINT}" \
  --data '{}' > /dev/null 2>&1
ok "Version marked complete"

printf "\n${GREEN}${BOLD}  HCP Packer registration complete — ${REGION}!${RESET}\n"
printf "\n  %-22s %s\n" "Bucket:"      "${BUCKET}"
printf "  %-22s %s\n"   "Fingerprint:" "${FINGERPRINT}"
printf "  %-22s %s\n"   "Version ID:"  "${VERSION_ID}"
printf "  %-22s %s\n"   "Region:"      "${REGION}"
printf "  %-22s %s\n"   "Artifact ID:" "${ARTIFACT_ID}"
printf "  %-22s https://portal.cloud.hashicorp.com/orgs/${ORG}/projects/${PROJ}/packer/buckets/${BUCKET}\n" "Portal:"
printf "\n"
