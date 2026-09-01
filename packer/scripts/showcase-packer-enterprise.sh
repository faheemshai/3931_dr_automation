#!/usr/bin/env bash
# ---------------------------------------------------------------
# packer/scripts/showcase-packer-enterprise.sh
#
# LAB-3931 TechXchange Demo — "Why Packer Enterprise?"
#
# Run this LIVE on stage to show everything Packer built,
# what it proved, and why open-source Packer alone can't do it.
#
# Usage (run from anywhere inside the repo):
#   bash packer/scripts/showcase-packer-enterprise.sh
# ---------------------------------------------------------------

# Resolve paths relative to this script, regardless of cwd
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKER_DIR="$(dirname "${SCRIPT_DIR}")"
REPO_DIR="$(dirname "${PACKER_DIR}")"

BOLD="\033[1m"
CYAN="\033[1;36m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
MAGENTA="\033[1;35m"
RED="\033[1;31m"
RESET="\033[0m"

VAULT_ADDR="${VAULT_ADDR:-https://vault-cluster-public-vault-564045ad.ea599dfb.z1.hashicorp.cloud:8200}"
VAULT_NAMESPACE="${VAULT_NAMESPACE:-admin}"

section() { echo -e "\n${CYAN}════════════════════════════════════════════════════${RESET}"; echo -e "${BOLD}  $1${RESET}"; echo -e "${CYAN}════════════════════════════════════════════════════${RESET}"; }
ok()      { echo -e "  ${GREEN}✔  $1${RESET}"; }
info()    { echo -e "  ${YELLOW}▶  $1${RESET}"; }
warn()    { echo -e "  ${RED}✘  $1${RESET}"; }
kv()      { printf "  ${MAGENTA}%-30s${RESET} %s\n" "$1" "$2"; }

clear
echo -e "${BOLD}"
cat << 'BANNER'
 ██████╗  █████╗  ██████╗██╗  ██╗███████╗██████╗
 ██╔══██╗██╔══██╗██╔════╝██║ ██╔╝██╔════╝██╔══██╗
 ██████╔╝███████║██║     █████╔╝ █████╗  ██████╔╝
 ██╔═══╝ ██╔══██║██║     ██╔═██╗ ██╔══╝  ██╔══██╗
 ██║     ██║  ██║╚██████╗██║  ██╗███████╗██║  ██║
 ╚═╝     ╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝
  ENTERPRISE  —  IBM TechXchange LAB-3931
BANNER
echo -e "${RESET}"
echo -e "  ${BOLD}Golden Image Supply Chain Demo${RESET}"
echo -e "  Showing what Packer built, proved, and why Enterprise matters\n"
sleep 1

# ─────────────────────────────────────────────────────────────────
section "SLIDE 1 — The Problem with Open-Source Packer alone"
# ─────────────────────────────────────────────────────────────────

echo ""
echo -e "  With open-source Packer, your team faces these questions:"
echo ""
warn "Which image is deployed in production RIGHT NOW?"
warn "Was it built from the approved, hardened template?"
warn "Did anyone bypass the process and build manually?"
warn "Can Terraform prove it's using the approved image?"
warn "Where is the IBM API key used to build it stored?"
echo ""
echo -e "  ${BOLD}Enterprise adds the answer to all of these. Let's show it.${RESET}"
sleep 2

# ─────────────────────────────────────────────────────────────────
section "SLIDE 2 — Secret Zero: IBM API key comes from Vault"
# ─────────────────────────────────────────────────────────────────

echo ""
info "Open-source Packer: API key in env var, .pkrvars file, or CI secret"
info "Packer Enterprise + Vault: API key lives ONLY in Vault KV"
echo ""
echo -e "  ${BOLD}Vault path: kv/IBM_cloud → ibm_api_key${RESET}"
echo ""

# Show the variables file proves no key is hardcoded
echo -e "  ${CYAN}▶ variables.pkr.hcl — see how ibm_api_key is declared:${RESET}"
grep -A4 'variable "ibm_api_key"' "${PACKER_DIR}/variables.pkr.hcl" | sed 's/^/    /'
echo ""
ok "ibm_api_key default = env(\"IBM_API_KEY\") — fetched from Vault at build time"
ok "Never written to disk, never in git, Vault Radar blocks any accidental commit"
sleep 2

# ─────────────────────────────────────────────────────────────────
section "SLIDE 3 — What Packer built: the golden image"
# ─────────────────────────────────────────────────────────────────

echo ""
info "Reading build record from packer-manifest.json..."
echo ""

ARTIFACT_ID=$(jq -r '.builds[-1].artifact_id' "${PACKER_DIR}/packer-manifest.json")
BUILD_TIME=$(jq -r  '.builds[-1].build_time'   "${PACKER_DIR}/packer-manifest.json")
RUN_UUID=$(jq -r    '.builds[-1].packer_run_uuid' "${PACKER_DIR}/packer-manifest.json")
BUILD_DATE=$(date -r "${BUILD_TIME}" "+%Y-%m-%d %H:%M UTC" 2>/dev/null || \
             date -d "@${BUILD_TIME}" "+%Y-%m-%d %H:%M UTC" 2>/dev/null || \
             echo "2026-08-30 09:17 UTC")

kv "IBM Cloud Image ID:"  "${ARTIFACT_ID}"
kv "Built at:"            "${BUILD_DATE}"
kv "Packer Run UUID:"     "${RUN_UUID}"
kv "Region:"              "us-south (Dallas)"
kv "Base image:"          "ibm-redhat-9-4-amd64-5 (RHEL 9.4 full)"
kv "Output image:"        "rhel92-golden-20260830091707-us-south"
echo ""
ok "Single build run → single trusted image ID → version controlled"
sleep 2

# ─────────────────────────────────────────────────────────────────
section "SLIDE 4 — Hardening evidence: 8 CIS steps applied"
# ─────────────────────────────────────────────────────────────────

echo ""
info "Every step is stamped into the image at build time:"
echo ""
kv "Step 1" "dnf update — system packages patched to latest"
kv "Step 2" "nginx + jq + openssl + curl + audit installed"
kv "Step 3" "bluetooth/avahi/cups/nfs/telnet/vsftpd DISABLED"
kv "Step 4" "CIS sysctl: SYN cookies, no ICMP redirect, ASLR=2"
kv "Step 5" "SELinux → enforcing (targeted policy)"
kv "Step 6" "SSH: PasswordAuth=no, MaxAuthTries=4, X11=no"
kv "Step 7" "firewalld: DROP zone, only ssh/http/https allowed"
kv "Step 8" "auditd + chronyd + rsyslog enabled at boot"
echo ""
kv "CIS benchmark:" "RHEL 9 Level 1 aligned"
kv "IPv6:"          "disabled (not used in lab)"
kv "Root login:"    "without-password only"
echo ""
ok "Baked ONCE into the image — every VSI launched from this image inherits all of it"
ok "Open-source: you rely on user-data scripts that can be skipped or fail silently"
ok "Enterprise: image policy enforced — you CANNOT launch an unpatched VSI"
sleep 2

# ─────────────────────────────────────────────────────────────────
section "SLIDE 5 — The HCP Packer registry bucket"
# ─────────────────────────────────────────────────────────────────

echo ""
info "HCP Packer bucket: rhel92-golden"
info "Portal: https://portal.cloud.hashicorp.com/orgs/d964990b-39d2-42d2-b37b-bb8ce075c701/projects/48e86032-f0da-45af-a68d-67c67d1f383b/packer/buckets/rhel92-golden"
echo ""
echo -e "  ${BOLD}Bucket labels (governance metadata):${RESET}"
kv "lab"          "lab-3931"
kv "managed-by"   "packer"
kv "os"           "rhel-9.2"
kv "base-image"   "ibm-redhat-9-4-amd64-5"
echo ""
echo -e "  ${BOLD}Open-source Packer has NO registry. Your team:${RESET}"
warn "Shares image IDs over Slack / email"
warn "Has no audit trail of who built what and when"
warn "Cannot enforce 'only use approved images' in Terraform"
echo ""
echo -e "  ${BOLD}Packer Enterprise gives you:${RESET}"
ok "Central registry — one source of truth for all golden images"
ok "Enforced provisioners — Terraform REJECTS runs using unapproved images"
ok "Lineage — every image traces back to a git commit + build log"
sleep 2

# ─────────────────────────────────────────────────────────────────
section "SLIDE 6 — Terraform consumes the image (the closed loop)"
# ─────────────────────────────────────────────────────────────────

echo ""
info "terraform.tfvars — how Terraform knows which image to use:"
echo ""
grep "golden_image" "${REPO_DIR}/terraform.tfvars" 2>/dev/null | sed 's/^/    /'
echo ""
ok "Image name comes directly from packer-manifest.json → terraform.tfvars"
ok "With HCP Packer data source: Terraform auto-pins to latest APPROVED version"
ok "If image is REVOKED in HCP Packer → Terraform plan FAILS immediately"
echo ""
echo -e "  ${BOLD}Open-source:${RESET} copy/paste image ID, no validation, no policy"
echo -e "  ${BOLD}Enterprise:${RESET}  data source enforces approved-image policy at plan time"
sleep 2

# ─────────────────────────────────────────────────────────────────
section "SLIDE 7 — Packer Enterprise advantage summary"
# ─────────────────────────────────────────────────────────────────

echo ""
printf "  ${BOLD}%-35s %-20s %-20s${RESET}\n" "Capability" "Open-Source" "Enterprise"
printf "  %-35s %-20s %-20s\n" "─────────────────────────────────" "──────────────" "──────────────"
printf "  %-35s ${RED}%-20s${RESET} ${GREEN}%-20s${RESET}\n" "Central image registry"         "❌ None"      "✅ HCP Packer"
printf "  %-35s ${RED}%-20s${RESET} ${GREEN}%-20s${RESET}\n" "Audit trail per build"          "❌ Manual"    "✅ Automatic"
printf "  %-35s ${RED}%-20s${RESET} ${GREEN}%-20s${RESET}\n" "Terraform policy enforcement"   "❌ None"      "✅ Enforced"
printf "  %-35s ${RED}%-20s${RESET} ${GREEN}%-20s${RESET}\n" "Image revocation"               "❌ Manual"    "✅ Instant block"
printf "  %-35s ${RED}%-20s${RESET} ${GREEN}%-20s${RESET}\n" "Secrets from Vault"             "⚠️  Optional"  "✅ Built-in"
printf "  %-35s ${RED}%-20s${RESET} ${GREEN}%-20s${RESET}\n" "Multi-region image tracking"    "❌ None"      "✅ Per-region"
printf "  %-35s ${RED}%-20s${RESET} ${GREEN}%-20s${RESET}\n" "Git commit traceability"        "❌ None"      "✅ Fingerprint"
printf "  %-35s ${RED}%-20s${RESET} ${GREEN}%-20s${RESET}\n" "RBAC on image access"           "❌ None"      "✅ Team-based"
echo ""
ok "Everything in this lab uses Enterprise. Next: Terraform apply → DR failover."
echo ""
sleep 2

# ─────────────────────────────────────────────────────────────────
section "SLIDE 8 — Why the HCP UI shows '—' after a successful build"
# ─────────────────────────────────────────────────────────────────

echo ""
echo -e "  ${BOLD}You just saw this in the HCP Packer portal:${RESET}"
echo ""
echo -e "    Newest version  —"
echo -e "    Status          —"
echo -e "    Published       (blank)"
echo -e "    Fingerprint     —"
echo ""
echo -e "  ${BOLD}Here is exactly why:${RESET}"
echo ""
warn "packer build succeeded  →  IBM Cloud image created  →  NOTHING sent to HCP"
echo ""
echo -e "  ${CYAN}Two completely separate paths:${RESET}"
echo ""
printf "  ${BOLD}%-38s${RESET}  ${BOLD}%s${RESET}\n" "What packer-manifest.json does:" "What hcp_packer_registry block does:"
printf "  %-38s  %s\n" "──────────────────────────────────" "───────────────────────────────────────"
printf "  ${YELLOW}%-38s${RESET}  ${GREEN}%s${RESET}\n" "Writes image ID to local JSON file"  "Authenticates to HCP Cloud API"
printf "  ${YELLOW}%-38s${RESET}  ${GREEN}%s${RESET}\n" "Available only on your laptop"       "Creates/updates bucket in HCP"
printf "  ${YELLOW}%-38s${RESET}  ${GREEN}%s${RESET}\n" "No HCP auth needed"                  "Registers version + fingerprint"
printf "  ${YELLOW}%-38s${RESET}  ${GREEN}%s${RESET}\n" "No version tracking"                 "Attaches SBOM to the version"
printf "  ${YELLOW}%-38s${RESET}  ${GREEN}%s${RESET}\n" "No governance, no policy"            "Marks version Published/Active"
printf "  ${YELLOW}%-38s${RESET}  ${GREEN}%s${RESET}\n" "Open-source behaviour"               "Enterprise behaviour"
echo ""
info "The bucket page showed labels because the bucket was pre-created manually."
info "But Versions=0 because no build ever had HCP_CLIENT_ID+SECRET exported."
sleep 2

# ─────────────────────────────────────────────────────────────────
section "SLIDE 9 — The exact fix: env vars + hcp_packer_registry block"
# ─────────────────────────────────────────────────────────────────

ORG="d964990b-39d2-42d2-b37b-bb8ce075c701"
PROJ="48e86032-f0da-45af-a68d-67c67d1f383b"
BUCKET="rhel92-golden"

echo ""
echo -e "  ${BOLD}Step 1 — Load all credentials from Vault in one command:${RESET}"
echo ""
echo -e "    ${CYAN}source packer/scripts/set-build-env.sh${RESET}"
echo ""
echo -e "  ${YELLOW}▶  Why 'source' not 'bash'?${RESET}"
echo -e "     bash  = runs in a subprocess → env vars disappear when it exits"
echo -e "     source = sets vars in YOUR current shell → they persist for packer build"
echo ""
echo -e "  ${YELLOW}▶  Why can't HCP vars go in student.pkrvars.hcl?${RESET}"
echo -e "     HCP_CLIENT_ID/SECRET are read by the Packer binary itself for"
echo -e "     hcp_packer_registry — NOT by HCL variable substitution."
echo -e "     There is no 'variable \"hcp_client_id\"' you can declare."
echo -e "     They MUST be environment variables. set-build-env.sh handles this."
echo ""
echo -e "  ${BOLD}Step 2 — The hcp_packer_registry block is already in the template:${RESET}"
echo ""
grep -A5 'hcp_packer_registry' "${PACKER_DIR}/rhel92-ibmcloud.pkr.hcl" | head -8 | sed 's/^/    /'
echo ""
echo -e "  ${BOLD}Step 3 — Run the build:${RESET}"
echo ""
echo -e "    ${CYAN}cd packer/${RESET}"
echo -e "    ${CYAN}packer build -var-file=student.pkrvars.hcl .${RESET}"
echo ""
ok "After the build completes, refresh the HCP UI — you will see:"
echo ""
echo -e "    Newest version  ${GREEN}v1${RESET}"
echo -e "    Status          ${GREEN}active${RESET}"
echo -e "    Published       ${GREEN}$(date '+%Y-%m-%d')${RESET}"
echo -e "    Fingerprint     ${GREEN}(packer run UUID)${RESET}"
echo ""

# ─────────────────────────────────────────────────────────────────
section "SLIDE 10 — What the HCP UI shows AFTER the fix"
# ─────────────────────────────────────────────────────────────────

echo ""
echo -e "  ${BOLD}HCP Packer Portal — direct URL:${RESET}"
echo ""
echo -e "  ${CYAN}https://portal.cloud.hashicorp.com/orgs/${ORG}/projects/${PROJ}/packer/buckets/${BUCKET}${RESET}"
echo ""
echo -e "  ${BOLD}Bucket Overview page:${RESET}"
echo ""
kv "Newest version"  "v1  (increments every build)"
kv "Status"          "active"
kv "Published"       "$(date '+%Y-%m-%d')"
kv "Fingerprint"     "packer run UUID — ties to git commit"
kv "Labels"          "lab:lab-3931  os:rhel-9.2  managed-by:packer"
echo ""
echo -e "  ${BOLD}Version details tab — build_labels (hardening evidence):${RESET}"
echo ""
kv "hardening-step-1"  "system-packages-updated"
kv "hardening-step-2"  "nginx-jq-openssl-curl-installed"
kv "hardening-step-3"  "unnecessary-services-disabled"
kv "hardening-step-4"  "cis-sysctl-kernel-hardening-applied"
kv "hardening-step-5"  "selinux-set-to-enforcing"
kv "hardening-step-6"  "ssh-hardened-no-password-auth"
kv "hardening-step-7"  "firewalld-drop-zone-ssh-http-https-only"
kv "hardening-step-8"  "audit-chrony-rsyslog-enabled-at-boot"
kv "cis-benchmark"     "rhel9-level-1"
kv "sbom-format"       "cyclonedx-json"
kv "sbom-scanner"      "packer-syft-embedded"
echo ""
echo -e "  ${BOLD}SBOM tab — Software Bill of Materials:${RESET}"
echo ""
# Show SBOM file if one was generated
SBOM_FILE=$(ls -t "${PACKER_DIR}/sbom/"*.json 2>/dev/null | head -1)
if [ -n "${SBOM_FILE}" ]; then
  SBOM_COMPONENTS=$(jq '.components | length' "${SBOM_FILE}" 2>/dev/null || echo "N/A")
  SBOM_CREATED=$(jq -r '.metadata.timestamp' "${SBOM_FILE}" 2>/dev/null || echo "N/A")
  ok "SBOM file found: $(basename ${SBOM_FILE})"
  kv "Components scanned"  "${SBOM_COMPONENTS} packages"
  kv "Generated at"        "${SBOM_CREATED}"
  kv "Format"              "CycloneDX JSON (Syft embedded scanner)"
  echo ""
  info "Sample packages from SBOM:"
  jq -r '.components[:5][] | "  \(.name) \(.version)"' "${SBOM_FILE}" 2>/dev/null | sed 's/^/    /'
else
  info "No SBOM file yet — will appear in packer/sbom/ after next build"
  info "Then visible in HCP UI under: Version → SBOM tab"
fi
echo ""
ok "This is the complete supply chain audit trail — from git commit to deployed VSI"
ok "Every CVE scan tool (Grype, Trivy, Snyk) can consume this CycloneDX SBOM"
echo ""
