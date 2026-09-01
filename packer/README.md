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
# Edit student.pkrvars.hcl — set student_id (ibm_api_key pre-filled for lab)

# 2. Export the IBM API key from Vault
export IBM_API_KEY=$(vault kv get -namespace=admin -mount=kv -field=ibm_api_key IBM_cloud)

# 3. Initialise plugins (first time only)
cd packer/
packer init .

# 4. Validate the template
packer validate -var-file=student.pkrvars.hcl .

# 5. Build
packer build -var-file=student.pkrvars.hcl .
```

After a successful build, the golden image appears in:
- **IBM Cloud console** → VPC Infrastructure → Custom Images
- **`packer-manifest.json`** — full build record with image ID, timestamp, run UUID

---

## What gets built

The build VSI runs [`scripts/harden-rhel92.sh`](scripts/harden-rhel92.sh) which applies
8 CIS-aligned hardening steps, then the image is captured.

| Step | What happens |
|------|-------------|
| 1 | `dnf update` — all packages patched to latest |
| 2 | `nginx`, `jq`, `openssl`, `curl`, `auditd` installed |
| 3 | `bluetooth`, `avahi`, `cups`, `telnet`, `vsftpd` disabled |
| 4 | CIS sysctl: SYN cookies, no ICMP redirect, ASLR=2, IPv6 disabled |
| 5 | SELinux → **enforcing** (targeted policy) |
| 6 | SSH: `PasswordAuthentication no`, `MaxAuthTries 4`, `X11Forwarding no` |
| 7 | firewalld: **drop** zone — only `ssh/http/https` allowed |
| 8 | `auditd`, `chronyd`, `rsyslog` enabled at boot |

Build metadata is stamped into `/etc/os-release` on every image:
```
LAB_BUILD_IMAGE=rhel92-golden-<timestamp>
LAB_BUILD_DATE=<timestamp>
LAB_STUDENT_ID=student-XX
```

A **CycloneDX SBOM** (Software Bill of Materials) is generated automatically
using `packer sbom-generate` (embedded Syft scanner) and saved to `sbom/`.
The SBOM inventories every installed package and is available for CVE scanning
tools such as Grype, Trivy, and Snyk.

---

## HCP Packer registry

The IBM Cloud Packer plugin (v3.7.0) does not implement the HCP artifact
interface, so the `hcp_packer_registry` build block cannot be used. Instead:

1. The build writes `packer-manifest.json` with the IBM Cloud image ID
2. The **lab instructor** registers the build in the HCP Packer portal UI
   using the image ID and fingerprint from `packer-manifest.json`
3. Students interact with the registered version via `demo-hcp-packer.sh`

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

## Demo script

Run the full TechXchange showcase from anywhere in the repo:

```bash
sh packer/scripts/demo-hcp-packer.sh
```

8 sections covering: the problem open-source Packer can't solve, Vault secret
injection, the golden image artifact, CIS hardening evidence, SBOM supply chain,
live HCP registry query, Terraform closed loop, and the Enterprise advantage table.
