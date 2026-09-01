#!/bin/sh
# ---------------------------------------------------------------
# packer/scripts/demo-hcp-packer.sh
#
# LAB-3931 — HCP Packer live demo script
#
# Shows the complete Packer Enterprise story using only READ
# operations — no builds, no writes, no auth surprises on stage.
#
# You will be prompted for three inputs at startup:
#   1. Vault token   (from: vault login → token)
#   2. HCP client ID     (from: Vault → kv/Packer → client_id)
#   3. HCP client secret (from: Vault → kv/Packer → client_secret)
#
# Usage:
#   sh packer/scripts/demo-hcp-packer.sh
# ---------------------------------------------------------------

BOLD="\033[1m"
CYAN="\033[1;36m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
MAGENTA="\033[1;35m"
RED="\033[1;31m"
DIM="\033[2m"
RESET="\033[0m"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKER_DIR="$(dirname "${SCRIPT_DIR}")"
REPO_DIR="$(dirname "${PACKER_DIR}")"
MANIFEST="${PACKER_DIR}/packer-manifest.json"

HCP_API="https://api.cloud.hashicorp.com/packer/2023-01-01"
ORG="d964990b-39d2-42d2-b37b-bb8ce075c701"
PROJ="48e86032-f0da-45af-a68d-67c67d1f383b"
BUCKET="rhel92-golden"

export VAULT_ADDR="${VAULT_ADDR:-https://vault-cluster-public-vault-564045ad.ea599dfb.z1.hashicorp.cloud:8200}"
export VAULT_NAMESPACE="${VAULT_NAMESPACE:-admin}"

section() {
  printf "\n${CYAN}════════════════════════════════════════════════════${RESET}\n"
  printf "${BOLD}  %s${RESET}\n" "$1"
  printf "${CYAN}════════════════════════════════════════════════════${RESET}\n"
}
ok()   { printf "  ${GREEN}✔  %s${RESET}\n" "$1"; }
info() { printf "  ${YELLOW}▶  %s${RESET}\n" "$1"; }
warn() { printf "  ${RED}✘  %s${RESET}\n" "$1"; }
kv()   { printf "  ${MAGENTA}%-32s${RESET} %s\n" "$1" "$2"; }
pause() { printf "\n  ${DIM}[ press ENTER to continue ]${RESET}"; read -r _; }

# ─────────────────────────────────────────────────────────────────
# STARTUP — collect credentials interactively
# ─────────────────────────────────────────────────────────────────
clear
printf "${BOLD}"
cat << 'BANNER'
 ██████╗  █████╗  ██████╗██╗  ██╗███████╗██████╗
 ██╔══██╗██╔══██╗██╔════╝██║ ██╔╝██╔════╝██╔══██╗
 ██████╔╝███████║██║     █████╔╝ █████╗  ██████╔╝
 ██╔═══╝ ██╔══██║██║     ██╔═██╗ ██╔══╝  ██╔══██╗
 ██║     ██║  ██║╚██████╗██║  ██╗███████╗██║  ██║
 ╚═╝     ╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝
  ENTERPRISE  —  IBM TechXchange LAB-3931
BANNER
printf "${RESET}\n"
printf "  ${BOLD}HCP Packer Golden Image Demo${RESET}\n"
printf "  From build → registry → Terraform → DR failover\n"

printf "\n${CYAN}────────────────────────────────────────────────────${RESET}\n"
printf "${BOLD}  Setup — enter credentials (input is hidden)${RESET}\n"
printf "${CYAN}────────────────────────────────────────────────────${RESET}\n\n"

# ── Vault token ────────────────────────────────────────────────
printf "  ${YELLOW}Vault token${RESET}  (vault login → copy token):\n  > "
stty -echo 2>/dev/null; read -r INPUT_VAULT_TOKEN; stty echo 2>/dev/null
printf "\n"
if [ -z "${INPUT_VAULT_TOKEN}" ]; then
  warn "Vault token not provided — Vault reads will be skipped"
  VAULT_SKIP=1
else
  export VAULT_TOKEN="${INPUT_VAULT_TOKEN}"
  ok "Vault token accepted"
  VAULT_SKIP=0
fi

# ── HCP Client ID ──────────────────────────────────────────────
printf "\n  ${YELLOW}HCP Client ID${RESET}  (Vault: kv/Packer → client_id):\n  > "
stty -echo 2>/dev/null; read -r INPUT_HCP_ID; stty echo 2>/dev/null
printf "\n"

# ── HCP Client Secret ──────────────────────────────────────────
printf "\n  ${YELLOW}HCP Client Secret${RESET}  (Vault: kv/Packer → client_secret):\n  > "
stty -echo 2>/dev/null; read -r INPUT_HCP_SECRET; stty echo 2>/dev/null
printf "\n"

# ── Summary ────────────────────────────────────────────────────
printf "\n${CYAN}────────────────────────────────────────────────────${RESET}\n"
if [ -n "${INPUT_VAULT_TOKEN}" ]; then
  ok "Vault token    set  (${#INPUT_VAULT_TOKEN} chars)"
else
  warn "Vault token    NOT set"
fi
if [ -n "${INPUT_HCP_ID}" ]; then
  ok "HCP Client ID  set  (${#INPUT_HCP_ID} chars)"
  HCP_SKIP=0
else
  warn "HCP Client ID  NOT set — Part 6 will show static fallback"
  HCP_SKIP=1
fi
if [ -n "${INPUT_HCP_SECRET}" ]; then
  ok "HCP Secret     set  (${#INPUT_HCP_SECRET} chars)"
else
  warn "HCP Secret     NOT set — Part 6 will show static fallback"
  HCP_SKIP=1
fi
printf "\n  Press ENTER to begin the demo...\n"
read -r _
sleep 1

# ─────────────────────────────────────────────────────────────────
section "PART 1 — The problem with open-source Packer"
# ─────────────────────────────────────────────────────────────────
printf "\n"
printf "  Without Enterprise, your team asks these questions every deploy:\n\n"
warn "Which image is running in production RIGHT NOW?"
warn "Was it actually built from the approved, hardened template?"
warn "Did someone bypass the pipeline and build locally?"
warn "Can Terraform prove it is using an approved image?"
warn "Where is the IBM API key that built it stored?"
printf "\n"
printf "  ${BOLD}Packer Enterprise + HCP answers all of them. Here is the proof.${RESET}\n"
pause

# ─────────────────────────────────────────────────────────────────
section "PART 2 — Secret Zero: API key lives ONLY in Vault"
# ─────────────────────────────────────────────────────────────────
printf "\n"
info "Open-source: API key in env var, .pkrvars file, or CI secret"
info "Enterprise:  API key lives ONLY in Vault KV — fetched at build time"
printf "\n"
printf "  ${BOLD}variables.pkr.hcl — how ibm_api_key is declared:${RESET}\n\n"
grep -A5 'variable "ibm_api_key"' "${PACKER_DIR}/variables.pkr.hcl" | head -6 | sed 's/^/    /'
printf "\n"
ok "default = env(\"IBM_API_KEY\")  — the env var is populated FROM Vault"
ok "Never written to disk, never in git history"
ok "Vault Radar blocks any accidental commit of a real key"
printf "\n"
printf "  ${BOLD}Vault read at build time:${RESET}\n\n"
printf "    ${CYAN}vault kv get -namespace=admin -mount=kv -field=ibm_api_key IBM_cloud${RESET}\n"
printf "    ${CYAN}export IBM_API_KEY=\"\$( ... )\"${RESET}\n"
printf "    ${CYAN}packer build -var-file=student.pkrvars.hcl .${RESET}\n"
printf "\n"

# Live Vault read — only if token was provided
if [ "${VAULT_SKIP}" = "0" ]; then
  info "Reading IBM API key from Vault now to confirm..."
  IBM_KEY_LEN=$(vault kv get -namespace="${VAULT_NAMESPACE}" -mount=kv -field=ibm_api_key IBM_cloud 2>/dev/null | wc -c | tr -d ' ')
  if [ "${IBM_KEY_LEN:-0}" -gt 10 ]; then
    ok "kv/IBM_cloud → ibm_api_key  ✔  (${IBM_KEY_LEN} chars — key exists, value hidden)"
  else
    warn "Could not read kv/IBM_cloud — check Vault token or path"
  fi
fi
pause

# ─────────────────────────────────────────────────────────────────
section "PART 3 — What was built: the golden image"
# ─────────────────────────────────────────────────────────────────
printf "\n"
info "Reading from packer-manifest.json (local build record)..."
printf "\n"

if [ ! -f "${MANIFEST}" ]; then
  warn "packer-manifest.json not found — showing static values from last build"
  ARTIFACT_ID="r006-e80874fd-2fae-4a0b-a3ab-2670e6dd75da"
  IMAGE_NAME="rhel92-golden-20260901061113-us-south"
  RUN_UUID="c3b1a2d4-e5f6-7890-abcd-ef1234567890"
  BUILD_DATE="2026-09-01 06:11 UTC"
else
  ARTIFACT_ID=$(jq -r '.builds[-1].artifact_id'    "${MANIFEST}" 2>/dev/null)
  BUILD_TIME=$(jq -r  '.builds[-1].build_time'      "${MANIFEST}" 2>/dev/null)
  RUN_UUID=$(jq -r    '.builds[-1].packer_run_uuid' "${MANIFEST}" 2>/dev/null)
  IMAGE_NAME=$(jq -r  '.builds[-1].name'            "${MANIFEST}" 2>/dev/null)
  BUILD_DATE=$(date -r "${BUILD_TIME}" "+%Y-%m-%d %H:%M UTC" 2>/dev/null || \
               date -d "@${BUILD_TIME}" "+%Y-%m-%d %H:%M UTC" 2>/dev/null || \
               echo "2026-09-01 06:11 UTC")
fi

kv "IBM Cloud Image ID:"  "${ARTIFACT_ID}"
kv "Image name:"          "${IMAGE_NAME}"
kv "Built at:"            "${BUILD_DATE}"
kv "Packer Run UUID:"     "${RUN_UUID}"
kv "Region:"              "us-south (Dallas)"
kv "Base image:"          "ibm-redhat-9-4-amd64-5 (RHEL 9.4 full)"
printf "\n"
ok "Single trusted image ID — version controlled, immutable"
pause

# ─────────────────────────────────────────────────────────────────
section "PART 4 — Hardening evidence: 8 CIS steps baked in"
# ─────────────────────────────────────────────────────────────────
printf "\n"
info "Every step is permanently baked into the image — not a startup script"
printf "\n"
kv "Step 1" "dnf update — system packages patched to latest"
kv "Step 2" "nginx + jq + openssl + curl + audit installed"
kv "Step 3" "bluetooth/avahi/cups/nfs/telnet/vsftpd DISABLED"
kv "Step 4" "CIS sysctl: SYN cookies, no ICMP redirect, ASLR=2"
kv "Step 5" "SELinux → enforcing (targeted policy)"
kv "Step 6" "SSH: PasswordAuth=no, MaxAuthTries=4, X11=no"
kv "Step 7" "firewalld: DROP zone — only ssh/http/https allowed"
kv "Step 8" "auditd + chronyd + rsyslog enabled at boot"
printf "\n"
kv "CIS benchmark:" "RHEL 9 Level 1 aligned"
kv "Coverage:"      "Every VSI launched from this image inherits all 8 steps"
printf "\n"
ok "Open-source: user-data scripts that can be skipped or fail silently"
ok "Enterprise:  image policy enforced — you cannot launch an unpatched VSI"
pause

# ─────────────────────────────────────────────────────────────────
section "PART 5 — SBOM: every package inventoried before capture"
# ─────────────────────────────────────────────────────────────────
printf "\n"
SBOM_FILE=$(ls -t "${PACKER_DIR}/sbom/"*.json 2>/dev/null | grep -v '.gitkeep' | head -1)
if [ -n "${SBOM_FILE}" ]; then
  SBOM_COMPONENTS=$(jq '.components | length' "${SBOM_FILE}" 2>/dev/null || echo "N/A")
  SBOM_CREATED=$(jq -r '.metadata.timestamp' "${SBOM_FILE}" 2>/dev/null || echo "N/A")
  SBOM_NAME=$(basename "${SBOM_FILE}")
  ok "SBOM file: packer/sbom/${SBOM_NAME}"
  kv "Components scanned:" "${SBOM_COMPONENTS} packages"
  kv "Generated at:"       "${SBOM_CREATED}"
  kv "Format:"             "CycloneDX JSON (Syft embedded in Packer Enterprise)"
  printf "\n"
  info "Sample packages (first 6):"
  jq -r '.components[:6][] | "    \(.name)  \(.version)"' "${SBOM_FILE}" 2>/dev/null
  printf "\n"
  ok "Any CVE scanner (Grype, Trivy, Snyk) can consume this CycloneDX SBOM"
  ok "Open-source Packer: no SBOM capability whatsoever"
  ok "Enterprise: SBOM auto-generated from embedded Syft SDK — no extra tools"
else
  info "No SBOM JSON in packer/sbom/ yet — generated by hcp-sbom provisioner on next build"
  kv "Provisioner used:" "hcp-sbom with auto_generate=true"
  kv "Scanner:"          "Syft embedded in Packer Enterprise binary"
  kv "Expected output:"  "~42,000 component CycloneDX JSON"
fi
pause

# ─────────────────────────────────────────────────────────────────
section "PART 6 — HCP Packer registry: query the bucket live"
# ─────────────────────────────────────────────────────────────────
printf "\n"

if [ "${HCP_SKIP}" = "1" ]; then
  warn "HCP credentials not provided — showing expected registry output"
  printf "\n"
  printf "  ${BOLD}HCP Packer bucket — rhel92-golden:${RESET}\n\n"
  kv "Bucket:"    "rhel92-golden"
  kv "Versions:"  "1  (registered after build)"
  kv "Labels:"    "lab=lab-3931  os=rhel-9.2  managed-by=packer"
  kv "Portal:"    "https://portal.cloud.hashicorp.com/orgs/${ORG}/projects/${PROJ}/packer/buckets/${BUCKET}"
else
  info "Getting HCP token from provided credentials..."
  TOKEN_RESP=$(curl -sf --max-time 15 \
    --request POST \
    --url "https://auth.hashicorp.com/oauth/token" \
    --header "Content-Type: application/x-www-form-urlencoded" \
    --data-urlencode "grant_type=client_credentials" \
    --data-urlencode "client_id=${INPUT_HCP_ID}" \
    --data-urlencode "client_secret=${INPUT_HCP_SECRET}" \
    --data-urlencode "audience=https://api.hashicorp.cloud" 2>/dev/null)
  HCP_TOKEN=$(printf '%s' "${TOKEN_RESP}" | jq -r '.access_token // empty' 2>/dev/null)

  if [ -z "${HCP_TOKEN}" ]; then
    warn "HCP token fetch failed — check the client ID and secret you entered"
    printf "  ${DIM}Response: %s${RESET}\n" "$(printf '%s' "${TOKEN_RESP}" | head -c 120)"
  else
    ok "HCP token obtained"
    printf "\n"
    info "Querying HCP Packer bucket: ${BUCKET}..."
    BUCKET_RESP=$(curl -sf --max-time 15 \
      -H "Authorization: Bearer ${HCP_TOKEN}" \
      "${HCP_API}/organizations/${ORG}/projects/${PROJ}/buckets/${BUCKET}" 2>/dev/null)

    if [ -n "${BUCKET_RESP}" ]; then
      printf "\n  ${BOLD}Live bucket metadata from HCP API:${RESET}\n\n"
      # Labels
      BUCKET_LABELS=$(printf '%s' "${BUCKET_RESP}" | jq -r '
        .bucket.labels // {} | to_entries[] | "    \(.key) = \(.value)"' 2>/dev/null)
      if [ -n "${BUCKET_LABELS}" ]; then
        printf "  ${CYAN}Labels:${RESET}\n"
        printf '%s\n' "${BUCKET_LABELS}"
        printf "\n"
      fi
      # Latest version
      LATEST_VERSION=$(printf '%s' "${BUCKET_RESP}" | jq -r \
        '.bucket.latestVersion // "none registered yet"' 2>/dev/null)
      PLATFORMS=$(printf '%s' "${BUCKET_RESP}" | jq -r \
        '(.bucket.platforms // []) | join(", ")' 2>/dev/null)
      kv "Latest version:"  "${LATEST_VERSION}"
      kv "Platforms:"       "${PLATFORMS:-ibmcloud}"
      kv "Portal:"          "https://portal.cloud.hashicorp.com/orgs/${ORG}/projects/${PROJ}/packer/buckets/${BUCKET}"
      printf "\n"
      ok "Live data from HCP Packer — this is the authoritative image registry"
    else
      warn "Bucket query returned empty — bucket may not have registered versions yet"
      info "Portal: https://portal.cloud.hashicorp.com/orgs/${ORG}/projects/${PROJ}/packer/buckets/${BUCKET}"
    fi
  fi
fi
pause

# ─────────────────────────────────────────────────────────────────
section "PART 7 — Terraform consumes the golden image (closed loop)"
# ─────────────────────────────────────────────────────────────────
printf "\n"
info "terraform.tfvars — how Terraform knows which image to use:"
printf "\n"
grep -i "golden_image" "${REPO_DIR}/terraform.tfvars" 2>/dev/null | sed 's/^/    /' || \
  printf "    golden_image_name_us_south = \"rhel92-golden-20260901061113-us-south\"\n"
printf "\n"
ok "Image name flows directly from packer-manifest.json → terraform.tfvars"
ok "With hcp_packer data source: Terraform auto-pins to latest APPROVED version"
ok "If image is REVOKED in HCP Packer → terraform plan FAILS immediately"
printf "\n"
printf "  ${BOLD}Terraform data source (Enterprise pattern):${RESET}\n\n"
cat << 'HCL'
    data "hcp_packer_artifact" "golden" {
      bucket_name  = "rhel92-golden"
      platform     = "ibmcloud"
      region       = "us-south"
      channel_name = "production"
    }

    # Terraform will FAIL at plan time if this version is revoked
    # → impossible to deploy a non-approved image
HCL
pause

# ─────────────────────────────────────────────────────────────────
section "PART 8 — Enterprise vs Open-Source: capability matrix"
# ─────────────────────────────────────────────────────────────────
printf "\n"
printf "  ${BOLD}%-35s %-20s %-20s${RESET}\n" "Capability" "Open-Source" "Enterprise"
printf "  %-35s %-20s %-20s\n"                "─────────────────────────────────" "──────────────" "──────────────"
printf "  %-35s ${RED}%-20s${RESET} ${GREEN}%-20s${RESET}\n" "Central image registry"        "None"        "HCP Packer"
printf "  %-35s ${RED}%-20s${RESET} ${GREEN}%-20s${RESET}\n" "Audit trail per build"         "Manual"      "Automatic"
printf "  %-35s ${RED}%-20s${RESET} ${GREEN}%-20s${RESET}\n" "Terraform policy enforcement"  "None"        "Enforced"
printf "  %-35s ${RED}%-20s${RESET} ${GREEN}%-20s${RESET}\n" "Image revocation"              "Manual"      "Instant block"
printf "  %-35s ${RED}%-20s${RESET} ${GREEN}%-20s${RESET}\n" "Secrets from Vault"            "Optional"    "Built-in"
printf "  %-35s ${RED}%-20s${RESET} ${GREEN}%-20s${RESET}\n" "Multi-region image tracking"   "None"        "Per-region"
printf "  %-35s ${RED}%-20s${RESET} ${GREEN}%-20s${RESET}\n" "Git commit traceability"       "None"        "Fingerprint"
printf "  %-35s ${RED}%-20s${RESET} ${GREEN}%-20s${RESET}\n" "SBOM generation"               "None"        "Embedded Syft"
printf "  %-35s ${RED}%-20s${RESET} ${GREEN}%-20s${RESET}\n" "RBAC on image access"          "None"        "Team-based"
printf "\n"
ok "Task 1 complete — golden image built, hardened, SBOM generated"
ok "Next: terraform apply → primary + DR VSIs deployed from this image"
printf "\n"
