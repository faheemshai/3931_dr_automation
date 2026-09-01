# LAB-3931 — Task 1: Packer Golden Image

Builds a **hardened RHEL 9.2 golden image** on IBM Cloud VPC and registers it in
HCP Packer. The image is consumed by Terraform in Task 2 for both the primary
(us-south) and DR (eu-de) regions.

---

## Folder structure

```
packer/
├── rhel92-ibmcloud.pkr.hcl     # Main Packer template — build definition
├── variables.pkr.hcl           # All variable declarations with descriptions
├── student.pkrvars.hcl.example # Copy this → student.pkrvars.hcl, fill in values
├── student.pkrvars.hcl         # YOUR working copy — gitignored, never committed
│
├── scripts/
│   ├── harden-rhel92.sh        # Runs inside the build VSI — 8-step CIS hardening
│   └── demo-hcp-packer.sh      # Live demo script for TechXchange presentation
│
└── sbom/
    ├── .gitkeep                # Keeps directory tracked in git
    └── *.json                  # CycloneDX SBOM — generated at build time, gitignored
```

---

## Quick start

```bash
# 1. Copy and fill in your var file
cp student.pkrvars.hcl.example student.pkrvars.hcl
# Edit student.pkrvars.hcl — set student_id

# 2. Export all credentials from Vault
export IBM_API_KEY=$(vault kv get -namespace=admin -mount=kv -field=ibm_api_key IBM_cloud)
export HCP_CLIENT_ID=$(vault kv get -namespace=admin -mount=kv -field=client_id Packer)
export HCP_CLIENT_SECRET=$(vault kv get -namespace=admin -mount=kv -field=client_secret Packer)

# 3. Initialise plugins (first time only)
cd packer/
packer init .

# 4. Validate the template
packer validate -var-file=student.pkrvars.hcl .

# 5. Build — image is captured AND registered in HCP Packer automatically
packer build -var-file=student.pkrvars.hcl .
```

After a successful build:
- **IBM Cloud console** → VPC Infrastructure → Custom Images — image appears here
- **`packer-manifest.json`** — full build record with image ID, timestamp, run UUID
- **HCP Packer portal** → `rhel92-golden` bucket → new version registered automatically

---

## Build flow

The provisioner sequence inside the `build {}` block runs in this exact order:

```
packer build
│
├── provisioner "file"          Step 1 — upload harden-rhel92.sh to VSI
│
├── provisioner "shell"         Step 2 — run harden-rhel92.sh (8 CIS steps, ~20 min)
│
├── provisioner "shell"         Step 3 — stamp metadata into /etc/os-release
│                                         LAB_BUILD_IMAGE, LAB_BUILD_DATE, LAB_STUDENT_ID
│
├── provisioner "hcp-sbom"      Step 4 — generate SBOM of the hardened image state
│                                         auto_generate=true: Packer binary uploaded to
│                                         VSI, runs embedded Syft SDK, scans /, downloads
│                                         CycloneDX JSON to packer/sbom/, uploads to HCP
│
├── provisioner "shell"         Step 5 — pre-capture cleanup
│                                         (rm host keys, dnf clean, truncate bash_history)
│
│   ← IBM Cloud captures the image here ─────────────────────────────────────────────
│
├── post-processor "manifest"   writes packer-manifest.json (image ID, run UUID)
│
└── post-processor "shell-local" runs hcp-register-build.sh on your laptop
                                  → registers version + artifact in HCP Packer portal
```

### Hardening steps (Step 2)

[`scripts/harden-rhel92.sh`](scripts/harden-rhel92.sh) applies 8 CIS RHEL 9 Level 1 steps:

| # | What happens |
|---|-------------|
| 1 | `dnf update` — all packages patched to latest |
| 2 | `nginx`, `jq`, `openssl`, `curl`, `auditd` installed |
| 3 | `bluetooth`, `avahi`, `cups`, `telnet`, `vsftpd` disabled |
| 4 | CIS sysctl: SYN cookies, no ICMP redirect, ASLR=2, IPv6 disabled |
| 5 | SELinux → **enforcing** (targeted policy) |
| 6 | SSH: `PasswordAuthentication no`, `MaxAuthTries 4`, `X11Forwarding no` |
| 7 | firewalld: **drop** zone — only `ssh/http/https` allowed |
| 8 | `auditd`, `chronyd`, `rsyslog` enabled at boot |

### Metadata stamp (Step 3)

Stamped into `/etc/os-release` on every image:

```
LAB_BUILD_IMAGE=rhel92-golden-<timestamp>
LAB_BUILD_DATE=<timestamp>
LAB_STUDENT_ID=student-XX
```

### SBOM generation (Step 4)

Uses `provisioner "hcp-sbom"` with `auto_generate = true`:

- Packer uploads its own binary to the VSI — no extra tools needed on the build host
- Runs `packer sbom-generate` (embedded Syft SDK) — scans the full filesystem
- Downloads the **CycloneDX JSON** SBOM to `packer/sbom/` on your laptop
- Uploads the SBOM to HCP Packer and attaches it to the version automatically
- `packer/sbom/` is tracked in git via `.gitkeep`; generated `*.json` files are gitignored
- The SBOM captures the **hardened, final image state** — not the base image

Any CVE scanner (Grype, Trivy, Snyk) can consume the CycloneDX JSON directly.

---

## HCP Packer registry

The IBM Cloud Packer plugin (v3.7.0) does not implement the built-in
`hcp_packer_registry` block. Registration is handled instead by a
`post-processor "shell-local"` that runs **on your laptop** immediately
after image capture, calling the HCP REST API directly via
`scripts/hcp-register-build.sh`.

**How it works:**
1. `manifest` post-processor writes `packer-manifest.json` with the image ID
2. `shell-local` post-processor runs `hcp-register-build.sh` with the HCP creds
3. The script creates version → build → artifact → marks DONE in HCP
4. If `HCP_CLIENT_ID` / `HCP_CLIENT_SECRET` are not exported, the step is
   skipped gracefully — the build itself never fails

**Portal URL:**
```
https://portal.cloud.hashicorp.com/orgs/d964990b-39d2-42d2-b37b-bb8ce075c701
  /projects/48e86032-f0da-45af-a68d-67c67d1f383b
  /packer/buckets/rhel92-golden
```

---

## After the build — update Terraform

Copy the image name from the manifest into `terraform.tfvars`:

```bash
# Get the image name
jq -r '.builds[-1].name' packer/packer-manifest.json
```

Update `terraform.tfvars`:
```hcl
golden_image_name_us_south = "rhel92-golden-<timestamp>-us-south"
```

---

## Scripts

| Script | When it runs | What it does |
|---|---|---|
| `scripts/harden-rhel92.sh` | Inside build VSI | 8-step CIS RHEL 9 hardening |
| `scripts/hcp-register-build.sh` | Post-processor (local) | Registers build in HCP Packer via REST API |
| `scripts/demo-hcp-packer.sh` | Manually on stage | TechXchange live demo — 8 sections |

### Demo script

Run the full TechXchange showcase from anywhere in the repo:

```bash
sh packer/scripts/demo-hcp-packer.sh
```

8 sections covering: the problem open-source Packer can't solve, Vault secret
injection, the golden image artifact, CIS hardening evidence, SBOM supply chain,
live HCP registry query, Terraform closed loop, and the Enterprise advantage table.
