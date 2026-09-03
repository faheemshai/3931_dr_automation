# packer/ — Golden Image Build for LAB-3931

This directory contains everything needed to build and register the hardened
RHEL 9 golden image used by all LAB-3931 VSIs in both regions.

## Files

| File | Purpose |
|------|---------|
| `rhel92-ibmcloud.pkr.hcl` | Main Packer template — builds in us-south and eu-de |
| `variables.pkr.hcl` | All variable declarations |
| `packer-manifest.json` | Written after each build — records image IDs and run UUID |
| `student.pkrvars.hcl.example` | Example vars file — copy and fill in for a new build |
| `sbom/` | CycloneDX SBOM JSON written by Packer Enterprise `hcp-sbom` provisioner |
| `scripts/harden-rhel92.sh` | 8-step CIS RHEL 9 Level 1 hardening applied inside the build VSI |
| `scripts/hcp-register-build.sh` | Registers the finished build in the HCP Packer registry |
| `scripts/demo-hcp-packer.sh` | **Live demo script** — shows the full golden image story in 8 parts |

## Running the demo (read-only — no build required)

The demo script reads the committed `packer-manifest.json` and queries the live
HCP Packer registry. No Packer build needed.

```bash
# From the repo root:
sh packer/scripts/demo-hcp-packer.sh
```

You will be prompted only for your **Vault token**. HCP credentials are fetched
automatically from `kv/Packer` in Vault.

## What is baked into the image

See [`scripts/harden-rhel92.sh`](scripts/harden-rhel92.sh) for the full
hardening script. Summary:

- **Core packages installed:** nginx, jq, curl, openssl, ca-certificates,
  firewalld, chrony, rsyslog, audit
- **Services disabled:** bluetooth, avahi-daemon, cups, nfs-server, rpcbind,
  rsyncd, telnet, vsftpd, httpd
- **CIS sysctl hardening:** SYN cookies, no ICMP redirect, ASLR=2, IPv6 off
- **SSH hardened:** PasswordAuthentication=no, MaxAuthTries=4, X11=no
- **Firewalld:** DROP zone — only ssh/http/https allowed
- **Boot services:** nginx, auditd, chronyd, rsyslog, firewalld

## Golden image IDs (current build)

| Region | Image ID |
|--------|---------|
| us-south | `r006-fe8ccdb8-d39a-4c75-91d1-2f763b31f360` |
| eu-de | `r010-13c7e12e-1df5-4ca2-ba0b-478fa6c6ac6c` |

These values are set in [`../terraform.tfvars`](../terraform.tfvars) and are
consumed by Terraform at apply time.
