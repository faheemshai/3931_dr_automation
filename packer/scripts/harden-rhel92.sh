#!/usr/bin/env bash
# ---------------------------------------------------------------
# packer/scripts/harden-rhel92.sh
#
# LAB-3931 — RHEL 9.2 Golden Image Hardening Script
# Runs as root inside the temporary Packer build VSI.
#
# What this script does:
#   1. Full system update (dnf update)
#   2. Install required runtime packages (nginx, jq, curl, openssl)
#   3. Disable unnecessary / insecure services
#   4. Apply basic CIS-aligned kernel hardening (sysctl)
#   5. Configure SELinux to enforcing
#   6. Lock down SSH configuration
#   7. Enable and configure firewalld
#   8. Verify the image is ready (smoke test)
#
# The script is idempotent — safe to run more than once.
# ---------------------------------------------------------------
set -euo pipefail

LOG_PREFIX="[harden-rhel92]"
log() { echo "${LOG_PREFIX} $*"; }

log "=== Starting RHEL 9.2 hardening ==="
log "Kernel: $(uname -r)"
log "OS: $(cat /etc/redhat-release)"

# ═══════════════════════════════════════════════════════════════
# 1. Full system update
# ═══════════════════════════════════════════════════════════════
log "--- Step 1: System update ---"

# ── Physically disable EUS/E4S repos BEFORE any dnf call ─────
# IBM Cloud RHEL minimal images ship with EUS repo definitions that
# return HTTP 404 in some regions (e.g. eu-de). dnf downloads repo
# metadata BEFORE config-manager --disable takes effect, so we must
# edit the .repo files directly to prevent the 404 from aborting the
# entire dnf run.
log "  Disabling EUS/E4S repo files to prevent 404 metadata errors..."
for repo_file in /etc/yum.repos.d/*.repo; do
  [ -f "${repo_file}" ] || continue
  # Set enabled=0 for any section whose name contains eus, e4s, or aus
  python3 - "${repo_file}" <<'PYEOF' 2>/dev/null || true
import sys, re
path = sys.argv[1]
with open(path) as f:
    content = f.read()
# Match [section-name] headers containing eus/e4s/aus (case-insensitive)
# and set their enabled= line to 0, or add enabled=0 if missing
result = []
in_target = False
for line in content.splitlines():
    if re.match(r'^\[.*(?:eus|e4s|aus).*\]', line, re.IGNORECASE):
        in_target = True
        result.append(line)
    elif re.match(r'^\[', line):
        in_target = False
        result.append(line)
    elif in_target and re.match(r'^enabled\s*=', line, re.IGNORECASE):
        result.append('enabled=0')
    else:
        result.append(line)
with open(path, 'w') as f:
    f.write('\n'.join(result) + '\n')
PYEOF
done

# Belt-and-suspenders: also run config-manager disable
dnf config-manager --disable "*eus*" 2>/dev/null || true
dnf config-manager --disable "*e4s*" 2>/dev/null || true
dnf config-manager --disable "*aus*" 2>/dev/null || true

# Clean cached metadata so dnf re-reads the updated repo state
dnf clean metadata 2>/dev/null || true

log "  EUS/E4S/AUS repos disabled."

# Update using only the repos that are actually reachable
dnf update -y --disablerepo="*eus*" --disablerepo="*e4s*" --disablerepo="*aus*" \
    --nobest --skip-broken || \
  dnf update -y --disablerepo="*eus*" --disablerepo="*e4s*" --disablerepo="*aus*" \
    --skip-broken || true
log "System update complete."

# ═══════════════════════════════════════════════════════════════
# 2. Install required runtime packages
# ═══════════════════════════════════════════════════════════════
log "--- Step 2: Installing packages ---"

# Enable CRB (CodeReady Linux Builder) for additional packages — best effort
dnf config-manager --set-enabled crb 2>/dev/null || true
# Re-disable EUS/E4S/AUS in case enabling crb re-enabled them
dnf config-manager --disable "*eus*" 2>/dev/null || true
dnf config-manager --disable "*e4s*" 2>/dev/null || true
dnf config-manager --disable "*aus*" 2>/dev/null || true

# Install in two passes: core packages first (must succeed), then
# optional packages best-effort so a missing package in one region
# doesn't abort the entire build.
CORE_PKGS="nginx jq curl openssl ca-certificates firewalld chrony rsyslog audit"
OPT_PKGS="net-tools bind-utils unzip policycoreutils-python-utils setools-console"

DNF_DISABLE="--disablerepo=*eus* --disablerepo=*e4s* --disablerepo=*aus*"

# shellcheck disable=SC2086
dnf install -y ${DNF_DISABLE} ${CORE_PKGS}
log "Core packages installed."

# Optional packages — skip-broken so a 404 on one repo doesn't abort
# shellcheck disable=SC2086
dnf install -y ${DNF_DISABLE} --skip-broken --nobest ${OPT_PKGS} || \
  log "  Some optional packages skipped (not critical)."

log "Packages installed."

# ═══════════════════════════════════════════════════════════════
# 3. Disable unnecessary / insecure services
# ═══════════════════════════════════════════════════════════════
log "--- Step 3: Disabling unnecessary services ---"

DISABLE_SERVICES=(
  bluetooth
  avahi-daemon
  cups
  nfs-server
  rpcbind
  rsyncd
  telnet
  vsftpd
  httpd
)

for svc in "${DISABLE_SERVICES[@]}"; do
  if systemctl list-unit-files "${svc}.service" &>/dev/null; then
    systemctl stop "${svc}.service"    2>/dev/null || true
    systemctl disable "${svc}.service" 2>/dev/null || true
    log "  disabled: ${svc}"
  fi
done

# ═══════════════════════════════════════════════════════════════
# 4. Kernel hardening (CIS-aligned sysctl settings)
# ═══════════════════════════════════════════════════════════════
log "--- Step 4: Kernel hardening (sysctl) ---"

cat > /etc/sysctl.d/99-lab-hardening.conf <<'SYSCTL'
# ── LAB-3931 CIS-aligned kernel parameters ──────────────────────

# Disable IP source routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

# Disable ICMP redirect acceptance
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0

# Do not send ICMP redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Enable SYN cookies (SYN flood protection)
net.ipv4.tcp_syncookies = 1

# Ignore ICMP broadcast requests
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Log suspicious packets
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Disable IPv6 (not used in lab)
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1

# Restrict core dumps
fs.suid_dumpable = 0

# Enable address space layout randomization
kernel.randomize_va_space = 2
SYSCTL

sysctl --system
log "Sysctl hardening applied."

# ═══════════════════════════════════════════════════════════════
# 5. SELinux — enforce
# ═══════════════════════════════════════════════════════════════
log "--- Step 5: SELinux ---"

# Set to enforcing in the config file (takes effect on next boot)
sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config

# Set enforcing now (may already be enforcing on IBM Cloud RHEL)
setenforce 1 2>/dev/null || log "  setenforce 1 skipped (may be in permissive mode in build env)"

SELINUX_STATUS=$(getenforce 2>/dev/null || echo "unknown")
log "  SELinux mode: ${SELINUX_STATUS}"

# Allow nginx to network connect (needed for Vault agent reverse proxy)
setsebool -P httpd_can_network_connect 1 2>/dev/null || true

# ═══════════════════════════════════════════════════════════════
# 6. SSH hardening
# ═══════════════════════════════════════════════════════════════
log "--- Step 6: SSH hardening ---"

# Back up original config
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.orig

cat > /etc/ssh/sshd_config.d/99-lab-hardening.conf <<'SSHD'
# LAB-3931 SSH hardening
PermitRootLogin               without-password
PasswordAuthentication        no
PermitEmptyPasswords          no
ChallengeResponseAuthentication no
UsePAM                        yes
X11Forwarding                 no
MaxAuthTries                  4
LoginGraceTime                30
ClientAliveInterval           300
ClientAliveCountMax           2
AllowTcpForwarding            no
Protocol                      2
SSHD

# Validate the config before restarting
sshd -t
log "  SSH config validated."

# ═══════════════════════════════════════════════════════════════
# 7. Firewalld baseline
# ═══════════════════════════════════════════════════════════════
log "--- Step 7: Firewalld ---"

systemctl enable firewalld
systemctl start  firewalld

# Default zone: drop everything, then allow only what the lab needs
firewall-cmd --set-default-zone=drop
firewall-cmd --zone=drop --add-service=ssh       --permanent
firewall-cmd --zone=drop --add-service=http      --permanent
firewall-cmd --zone=drop --add-service=https     --permanent
firewall-cmd --reload
log "  Firewalld rules applied (ssh, http, https)."

# ═══════════════════════════════════════════════════════════════
# 8. Enable services needed at boot
# ═══════════════════════════════════════════════════════════════
log "--- Step 8: Enabling boot services ---"

systemctl enable nginx
systemctl enable auditd
systemctl enable chronyd
systemctl enable rsyslog

# ═══════════════════════════════════════════════════════════════
# 9. Smoke test — confirm key binaries are present
# ═══════════════════════════════════════════════════════════════
log "--- Step 9: Smoke test ---"

for bin in nginx jq curl openssl firewall-cmd; do
  if command -v "${bin}" &>/dev/null; then
    log "  OK: ${bin} $(${bin} --version 2>&1 | head -1)"
  else
    log "  FAIL: ${bin} not found"
    exit 1
  fi
done

log "=== Hardening complete ==="
log "Image is ready for Packer to capture."
