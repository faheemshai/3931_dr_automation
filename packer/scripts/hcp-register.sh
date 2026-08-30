#!/usr/bin/env bash
# ---------------------------------------------------------------
# packer/scripts/hcp-register.sh
#
# LAB-3931 — HCP Packer Registry registration for IBM Cloud plugin
#
# The IBM Cloud Packer plugin is NOT HCP-ready, so Packer's native
# hcp_packer_registry block cannot push artifact metadata. This script
# uses the HCP Packer REST API directly to:
#
#   1. Get an HCP OAuth2 token (client_credentials)
#   2. Ensure the bucket exists (upsert)
#   3. Create a new version (iteration) for this build fingerprint
#   4. Register the IBM Cloud image ID as the artifact
#   5. Mark the version COMPLETE so it shows as published
#
# Required env vars (all come from Vault — never hard-coded):
#   HCP_CLIENT_ID          — HCP service principal client ID
#   HCP_CLIENT_SECRET      — HCP service principal client secret
#   HCP_ORGANIZATION_ID    — from HCP portal URL
#   HCP_PROJECT_ID         — from HCP portal URL
#   IBM_IMAGE_ID           — set automatically by the shell-local post-processor
#   IBM_IMAGE_NAME         — set automatically by the shell-local post-processor
#   IBM_REGION             — set automatically by the shell-local post-processor
#   PACKER_BUILD_NAME      — set automatically by Packer
#   PACKER_RUN_UUID        — set automatically by Packer
#
# Usage (called automatically as a shell-local post-processor):
#   Not meant to be run manually.
# ---------------------------------------------------------------
set -euo pipefail

LOG="[hcp-register]"
log()  { echo "${LOG} $*"; }
die()  { echo "${LOG} ERROR: $*" >&2; exit 1; }

# ── 1. Validate required env vars ───────────────────────────────
for var in HCP_CLIENT_ID HCP_CLIENT_SECRET HCP_ORGANIZATION_ID HCP_PROJECT_ID \
           IBM_IMAGE_ID IBM_IMAGE_NAME IBM_REGION; do
  [ -n "${!var:-}" ] || die "Required env var \$${var} is not set"
done

BUCKET_NAME="rhel92-golden"
BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
FINGERPRINT="${PACKER_RUN_UUID:-$(uuidgen | tr '[:upper:]' '[:lower:]')}"

log "=== HCP Packer registration ==="
log "Bucket:      ${BUCKET_NAME}"
log "Image ID:    ${IBM_IMAGE_ID}"
log "Image Name:  ${IBM_IMAGE_NAME}"
log "Region:      ${IBM_REGION}"
log "Fingerprint: ${FINGERPRINT}"

HCP_API="https://api.cloud.hashicorp.com/packer/2023-01-01"
ORG="${HCP_ORGANIZATION_ID}"
PROJ="${HCP_PROJECT_ID}"

# ── 2. Get HCP OAuth2 token ──────────────────────────────────────
log "--- Fetching HCP token ---"
TOKEN_RESPONSE=$(curl -sf \
  --request POST \
  --url "https://auth.hashicorp.com/oauth/token" \
  --data "grant_type=client_credentials" \
  --data "client_id=${HCP_CLIENT_ID}" \
  --data "client_secret=${HCP_CLIENT_SECRET}" \
  --data "audience=https://api.hashicorp.cloud")

HCP_TOKEN=$(echo "${TOKEN_RESPONSE}" | jq -r '.access_token // empty')
[ -n "${HCP_TOKEN}" ] || die "Failed to get HCP token. Response: ${TOKEN_RESPONSE}"
log "Token obtained."

AUTH_HEADER="Authorization: Bearer ${HCP_TOKEN}"

# ── 3. Upsert bucket ────────────────────────────────────────────
log "--- Upserting bucket '${BUCKET_NAME}' ---"

BUCKET_PAYLOAD=$(jq -n \
  --arg name  "${BUCKET_NAME}" \
  --arg desc  "Hardened RHEL 9.2 golden image for LAB-3931 DR pipeline" \
  --arg lab   "lab-3931" \
  --arg mgr   "packer" \
  --arg os    "rhel-9.2" \
  --arg base  "${IBM_IMAGE_NAME}" \
  '{
    bucket_name: $name,
    description: $desc,
    labels: {
      "lab":        $lab,
      "managed-by": $mgr,
      "os":         $os,
      "base-image": $base
    }
  }')

curl -sf \
  --request PUT \
  --url "${HCP_API}/organizations/${ORG}/projects/${PROJ}/images/${BUCKET_NAME}" \
  --header "${AUTH_HEADER}" \
  --header "Content-Type: application/json" \
  --data "${BUCKET_PAYLOAD}" > /dev/null \
  && log "Bucket upserted." \
  || log "Bucket upsert returned non-2xx (may already exist — continuing)."

# ── 4. Create version (iteration) ───────────────────────────────
log "--- Creating version (fingerprint=${FINGERPRINT}) ---"

VERSION_PAYLOAD=$(jq -n \
  --arg fp "${FINGERPRINT}" \
  '{fingerprint: $fp}')

VERSION_RESPONSE=$(curl -sf \
  --request POST \
  --url "${HCP_API}/organizations/${ORG}/projects/${PROJ}/images/${BUCKET_NAME}/versions" \
  --header "${AUTH_HEADER}" \
  --header "Content-Type: application/json" \
  --data "${VERSION_PAYLOAD}")

VERSION_ID=$(echo "${VERSION_RESPONSE}" | jq -r '.version.id // .id // empty')
[ -n "${VERSION_ID}" ] || die "Failed to create version. Response: ${VERSION_RESPONSE}"
log "Version created: ${VERSION_ID}"

# ── 5. Create build record under the version ─────────────────────
log "--- Creating build record ---"

BUILD_PAYLOAD=$(jq -n \
  --arg component  "ibmcloud-vpc.${IBM_REGION}" \
  --arg packer_ver "1.16.0" \
  --arg status     "DONE" \
  '{
    component_type: $component,
    packer_run_uuid: $packer_ver,
    status: $status,
    labels: {
      "hardening-step-1":  "system-packages-updated",
      "hardening-step-2":  "nginx-jq-openssl-curl-installed",
      "hardening-step-3":  "unnecessary-services-disabled",
      "hardening-step-4":  "cis-sysctl-kernel-hardening-applied",
      "hardening-step-5":  "selinux-set-to-enforcing",
      "hardening-step-6":  "ssh-hardened-no-password-auth",
      "hardening-step-7":  "firewalld-drop-zone-ssh-http-https-only",
      "hardening-step-8":  "audit-chrony-rsyslog-enabled-at-boot",
      "cis-benchmark":     "rhel9-level-1",
      "password-auth":     "disabled",
      "ipv6":              "disabled",
      "selinux-policy":    "targeted",
      "x11-forwarding":    "disabled",
      "dr-lab":            "lab-3931",
      "primary-region":    "us-south",
      "dr-region":         "eu-de",
      "pipeline-stage":    "golden-image"
    }
  }')

BUILD_RESPONSE=$(curl -sf \
  --request POST \
  --url "${HCP_API}/organizations/${ORG}/projects/${PROJ}/images/${BUCKET_NAME}/versions/${VERSION_ID}/builds" \
  --header "${AUTH_HEADER}" \
  --header "Content-Type: application/json" \
  --data "${BUILD_PAYLOAD}")

BUILD_ID=$(echo "${BUILD_RESPONSE}" | jq -r '.build.id // .id // empty')
[ -n "${BUILD_ID}" ] || die "Failed to create build. Response: ${BUILD_RESPONSE}"
log "Build record created: ${BUILD_ID}"

# ── 6. Register the IBM Cloud image as the artifact ──────────────
log "--- Registering artifact: ${IBM_IMAGE_ID} ---"

ARTIFACT_PAYLOAD=$(jq -n \
  --arg image_id   "${IBM_IMAGE_ID}" \
  --arg image_name "${IBM_IMAGE_NAME}" \
  --arg region     "${IBM_REGION}" \
  '{
    external_identifier: $image_id,
    region: $region,
    labels: {
      "image-name": $image_name,
      "cloud":      "ibm-cloud",
      "service":    "vpc"
    }
  }')

curl -sf \
  --request POST \
  --url "${HCP_API}/organizations/${ORG}/projects/${PROJ}/images/${BUCKET_NAME}/versions/${VERSION_ID}/builds/${BUILD_ID}/artifacts" \
  --header "${AUTH_HEADER}" \
  --header "Content-Type: application/json" \
  --data "${ARTIFACT_PAYLOAD}" > /dev/null \
  && log "Artifact registered."

# ── 7. Mark build DONE ───────────────────────────────────────────
log "--- Marking build DONE ---"

curl -sf \
  --request PATCH \
  --url "${HCP_API}/organizations/${ORG}/projects/${PROJ}/images/${BUCKET_NAME}/versions/${VERSION_ID}/builds/${BUILD_ID}" \
  --header "${AUTH_HEADER}" \
  --header "Content-Type: application/json" \
  --data '{"status": "DONE"}' > /dev/null \
  && log "Build marked DONE."

# ── 8. Complete (publish) the version ───────────────────────────
log "--- Completing version ---"

curl -sf \
  --request PATCH \
  --url "${HCP_API}/organizations/${ORG}/projects/${PROJ}/images/${BUCKET_NAME}/versions/${VERSION_ID}" \
  --header "${AUTH_HEADER}" \
  --header "Content-Type: application/json" \
  --data '{"status": "active"}' > /dev/null \
  && log "Version marked active."

log "=== HCP Packer registration complete ==="
log "Portal: https://portal.cloud.hashicorp.com/orgs/${ORG}/projects/${PROJ}/packer/buckets/${BUCKET_NAME}"
log "Image ID: ${IBM_IMAGE_ID}"
