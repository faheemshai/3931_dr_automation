# ---------------------------------------------------------------
# packer/rhel92-ibmcloud.pkr.hcl
#
# LAB-3931 — Automating Disaster Recovery
# Builds a hardened RHEL 9.2 golden image and pushes it to IBM Cloud
# Image Registry in TWO regions simultaneously:
#   • us-south  (primary)
#   • eu-de     (DR)
#
# Builds are tracked in HCP Packer SaaS — every run creates a new
# image version in the "rhel92-golden" channel, available to
# Terraform via the HCP Packer data source in Task 2.
#
# HCP Packer authentication uses service principal env vars —
# NEVER hard-coded in this file:
#   export HCP_CLIENT_ID="<your-client-id>"
#   export HCP_CLIENT_SECRET="<your-client-secret>"
#
# Usage:
#   cd packer/
#   packer init .
#   packer build -var-file=student.pkrvars.hcl ./rhel92-ibmcloud.pkr.hcl
#
# After the build, note the two IBM Cloud image IDs from the
# packer-manifest.json output — supply them as Terraform variables
# in Task 2:
#   golden_image_id_us_south = "<us-south image ID>"
#   golden_image_id_eu_de    = "<eu-de image ID>"
#
# Fallback: if the build times out at 8 minutes, open the HCP Packer
# registry UI, navigate to the "rhel92-golden" bucket, and copy the
# pre-built image IDs for us-south and eu-de from the latest iteration.
# ---------------------------------------------------------------

# ── Required plugins ─────────────────────────────────────────────
packer {
  required_plugins {
    ibmcloud = {
      source  = "github.com/IBM/ibmcloud"
      version = ">= 3.0.0"
    }
  }
}

# ── Local values ─────────────────────────────────────────────────
locals {
  # Timestamp appended to every image name — makes each build immutable
  # and uniquely identifiable in IBM Cloud Image Registry.
  timestamp  = formatdate("YYYYMMDD-hhmm", timestamp())
  image_name = "${var.image_name_prefix}-${local.timestamp}"
}

# ═══════════════════════════════════════════════════════════════
# SOURCE BLOCKS
# Two identical sources — one per region.
# Packer builds them in parallel, producing one image per region.
# ═══════════════════════════════════════════════════════════════

# ── us-south (primary region) ────────────────────────────────────
source "ibmcloud-vpc" "rhel92_us_south" {
  # IBM Cloud API key — read from var (supplied via student.pkrvars.hcl,
  # which is gitignored). Never hard-coded here.
  api_key = var.ibm_api_key

  region = "us-south"
  zone   = var.us_south_zone    # default: us-south-1

  # IBM Cloud stock RHEL 9.2 minimal image as the build base.
  # Confirm the exact name: ibmcloud is images --visibility public | grep rhel-9-2
  base_image_name = var.base_image_name

  # Small profile for the temporary build VSI only — not for lab workloads.
  profile  = "cx2-2x4"    # Compute · 2 vCPU / 4 GB
  vpc_name = var.build_vpc_name_us_south

  communicator = "ssh"
  ssh_username = "root"

  # Output image stored in IBM Cloud Image Registry us-south
  image_name        = "${local.image_name}-us-south"
  resource_group_id = var.ibm_resource_group_id
}

# ── eu-de (DR region) ────────────────────────────────────────────
source "ibmcloud-vpc" "rhel92_eu_de" {
  api_key = var.ibm_api_key

  region = "eu-de"
  zone   = var.eu_de_zone    # default: eu-de-2

  base_image_name = var.base_image_name

  profile  = "cx2-2x4"
  vpc_name = var.build_vpc_name_eu_de

  communicator = "ssh"
  ssh_username = "root"

  # Output image stored in IBM Cloud Image Registry eu-de
  image_name        = "${local.image_name}-eu-de"
  resource_group_id = var.ibm_resource_group_id
}

# ═══════════════════════════════════════════════════════════════
# BUILD BLOCK
# ═══════════════════════════════════════════════════════════════
build {
  name = "rhel92-golden"

  sources = [
    "source.ibmcloud-vpc.rhel92_us_south",
    "source.ibmcloud-vpc.rhel92_eu_de",
  ]

  # ── HCP Packer registry ──────────────────────────────────────
  # Tracks every build as a versioned iteration in the HCP Packer
  # SaaS registry under the "rhel92-golden" bucket.
  #
  # Authentication is via environment variables only:
  #   HCP_CLIENT_ID     — HCP service principal client ID
  #   HCP_CLIENT_SECRET — HCP service principal client secret
  # Set these in your shell before running packer build.
  # They are NEVER written to this file or any committed file.
  hcp_packer_registry {
    bucket_name = "rhel92-golden"
    description = "Hardened RHEL 9.2 golden image for LAB-3931 DR pipeline"

    bucket_labels = {
      "os"          = "rhel-9.2"
      "lab"         = "3931"
      "managed-by"  = "packer"
    }

    build_labels = {
      "build-time"   = local.timestamp
      "student-id"   = var.student_id
      "base-image"   = var.base_image_name
    }
  }

  # ── Step 1: Upload hardening script ──────────────────────────
  provisioner "file" {
    source      = "${path.root}/scripts/harden-rhel92.sh"
    destination = "/tmp/harden-rhel92.sh"
  }

  # ── Step 2: Run hardening ────────────────────────────────────
  provisioner "shell" {
    execute_command = "chmod +x '{{ .Path }}'; {{ .Vars }} bash '{{ .Path }}'"
    inline = [
      "chmod +x /tmp/harden-rhel92.sh",
      "/tmp/harden-rhel92.sh",
    ]
    timeout = "20m"
  }

  # ── Step 3: Stamp build metadata into the image ──────────────
  provisioner "shell" {
    inline = [
      "echo 'LAB_BUILD_IMAGE=${local.image_name}' >> /etc/os-release",
      "echo 'LAB_BUILD_DATE=${local.timestamp}'   >> /etc/os-release",
      "echo 'LAB_STUDENT_ID=${var.student_id}'    >> /etc/os-release",
    ]
  }

  # ── Step 4: Final cleanup before image capture ───────────────
  provisioner "shell" {
    inline = [
      # Remove SSH host keys — regenerate automatically on each VSI's first boot
      "rm -f /etc/ssh/ssh_host_*",
      # Clear package cache, temp files, bash history
      "dnf clean all",
      "rm -rf /var/tmp/*",
      "truncate -s 0 /root/.bash_history",
      "sync",
    ]
  }

  # ── Post-processor: write local manifest ─────────────────────
  # Writes packer-manifest.json containing the image IDs for both
  # regions. Read this file after the build to get the IDs for
  # the Terraform golden_image_id_us_south / golden_image_id_eu_de
  # variables in Task 2.
  post-processor "manifest" {
    output     = "${path.root}/packer-manifest.json"
    strip_path = true
  }
}
