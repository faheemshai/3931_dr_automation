# ---------------------------------------------------------------
# packer/rhel92-ibmcloud.pkr.hcl
#
# LAB-3931 — Automating Disaster Recovery
# Builds a hardened RHEL 9.2 golden image and registers it in HCP
# Packer, pushing to IBM Cloud Image Registry in TWO regions:
#   • us-south  (primary)
#   • eu-de     (DR)
#
# HCP Packer authentication — env vars only, never in this file:
#   export HCP_CLIENT_ID="..."
#   export HCP_CLIENT_SECRET="..."
#
# Usage:
#   cd packer/
#   packer init .
#   packer validate -var-file=student.pkrvars.hcl .
#   packer build   -var-file=student.pkrvars.hcl .
#
# After the build completes, image IDs appear in packer-manifest.json
# and in the HCP Packer registry UI under the "rhel92-golden" bucket.
# Supply them as Terraform variables in Task 2:
#   golden_image_id_us_south = "..."
#   golden_image_id_eu_de    = "..."
# ---------------------------------------------------------------

# ── Required plugin ──────────────────────────────────────────────
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
  # Compact timestamp → unique, sortable image name every build
  timestamp  = regex_replace(timestamp(), "[- TZ:]", "")
  image_name = "${var.image_name_prefix}-${local.timestamp}"
}

# ═══════════════════════════════════════════════════════════════
# SOURCE BLOCKS — one per region, built in parallel
# ═══════════════════════════════════════════════════════════════

# ── us-south (primary) ───────────────────────────────────────────
source "ibmcloud-vpc" "rhel92_us_south" {
  # Auth — IBM Cloud API key (from student.pkrvars.hcl, gitignored)
  api_key = var.ibm_api_key

  # Target region
  region = "us-south"

  # Subnet in us-south where the temporary build VSI is created.
  # The subnet must have a public gateway so dnf can reach the internet.
  # Get the ID: ibmcloud is subnets --zone us-south-1 | grep <your-subnet>
  subnet_id = var.subnet_id_us_south

  # Resource group for the output image
  resource_group_id = var.ibm_resource_group_id

  # No extra security group — the default VPC security group is used.
  # Set to your build security group ID if your account requires it.
  security_group_id = ""

  # Base image: IBM Cloud stock RHEL 9.2
  vsi_base_image_name = var.base_image_name   # ibm-redhat-9-2-minimal-amd64-9

  # Temporary build VSI profile — small and fast; not the lab workload profile
  vsi_profile   = "cx2-2x4"
  vsi_interface = "public"

  # Output image name in IBM Cloud Image Registry
  image_name = "${local.image_name}-us-south"

  # SSH communicator settings
  communicator = "ssh"
  ssh_username = "root"
  ssh_port     = 22
  ssh_timeout  = "15m"

  # Overall build timeout (dnf update + package install can take ~15 min)
  timeout = "30m"
}

# ── eu-de (DR) ───────────────────────────────────────────────────
source "ibmcloud-vpc" "rhel92_eu_de" {
  api_key = var.ibm_api_key

  region = "eu-de"

  subnet_id         = var.subnet_id_eu_de
  resource_group_id = var.ibm_resource_group_id
  security_group_id = ""

  vsi_base_image_name = var.base_image_name
  vsi_profile         = "cx2-2x4"
  vsi_interface       = "public"

  image_name = "${local.image_name}-eu-de"

  communicator = "ssh"
  ssh_username = "root"
  ssh_port     = 22
  ssh_timeout  = "15m"

  timeout = "30m"
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
  # Tracks every run as a versioned iteration in the "rhel92-golden"
  # bucket. Credentials come from HCP_CLIENT_ID / HCP_CLIENT_SECRET
  # env vars — never written to any file.
  hcp_packer_registry {
    bucket_name = "rhel92-golden"
    description = "Hardened RHEL 9.2 golden image for LAB-3931 DR pipeline"

    bucket_labels = {
      "os"         = "rhel-9.2"
      "lab"        = "lab-3931"
      "managed-by" = "packer"
    }

    build_labels = {
      "build-time"  = local.timestamp
      "student-id"  = var.student_id
      "base-image"  = var.base_image_name
    }
  }

  # ── Step 1: Upload hardening script ──────────────────────────
  provisioner "file" {
    source      = "${path.root}/scripts/harden-rhel92.sh"
    destination = "/tmp/harden-rhel92.sh"
  }

  # ── Step 2: Run hardening ────────────────────────────────────
  provisioner "shell" {
    execute_command = "{{.Vars}} bash '{{.Path}}'"
    inline = [
      "chmod +x /tmp/harden-rhel92.sh",
      "/tmp/harden-rhel92.sh",
    ]
    timeout = "20m"
  }

  # ── Step 3: Stamp build metadata ────────────────────────────
  provisioner "shell" {
    execute_command = "{{.Vars}} bash '{{.Path}}'"
    inline = [
      "echo 'LAB_BUILD_IMAGE=${local.image_name}' >> /etc/os-release",
      "echo 'LAB_BUILD_DATE=${local.timestamp}'   >> /etc/os-release",
      "echo 'LAB_STUDENT_ID=${var.student_id}'    >> /etc/os-release",
    ]
  }

  # ── Step 4: Pre-capture cleanup ─────────────────────────────
  provisioner "shell" {
    execute_command = "{{.Vars}} bash '{{.Path}}'"
    inline = [
      # SSH host keys regenerate on each VSI's first boot
      "rm -f /etc/ssh/ssh_host_*",
      "dnf clean all",
      "rm -rf /var/tmp/*",
      "truncate -s 0 /root/.bash_history",
      "sync",
    ]
  }

  # ── Post-processor: local manifest ──────────────────────────
  # Writes packer-manifest.json with artifact IDs for both regions.
  # Use these IDs for the Terraform variables in Task 2.
  post-processor "manifest" {
    output     = "${path.root}/packer-manifest.json"
    strip_path = true
  }
}
