# ---------------------------------------------------------------
# packer/rhel92-ibmcloud.pkr.hcl
#
# LAB-3931 — Automating Disaster Recovery
# Builds a hardened RHEL 9.2 golden image and registers it in HCP
# Packer, pushing to IBM Cloud Image Registry.
#
# Regions built: controlled by var.build_regions
#   "us-south"       → primary only  (single-region test)
#   "eu-de"          → DR only
#   "us-south,eu-de" → both in parallel (full lab build)
#
# HCP Packer auth — env vars only, never in this file:
#   export HCP_CLIENT_ID="..."
#   export HCP_CLIENT_SECRET="..."
#
# Usage:
#   cd packer/
#   packer init .
#   packer validate -var-file=student.pkrvars.hcl .
#   packer build   -var-file=student.pkrvars.hcl .
#
# After the build, image IDs appear in packer-manifest.json and
# in the HCP Packer registry UI under the "rhel92-golden" bucket.
# Supply them as Terraform variables in Task 2.
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
  timestamp  = regex_replace(timestamp(), "[- TZ:]", "")
  image_name = "${var.image_name_prefix}-${local.timestamp}"

  # cloud-init user-data: fetch SSH keys from IBM Cloud metadata service
  # and write them to authorized_keys immediately at first boot.
  # This forces key injection before sshd starts — fixes the RHEL 9
  # minimal image timing race where cloud-init finishes too late.
  cloud_init_user_data = <<-USERDATA
    #!/bin/bash
    set -e
    mkdir -p /root/.ssh
    chmod 700 /root/.ssh
    # Fetch all SSH keys registered to this VSI from the metadata service
    KEYS=$(curl -sf -H "Metadata-Flavor: ibm" \
      "http://169.254.169.254/metadata/v1/keys?version=2022-03-01" \
      | python3 -c "import sys,json; [print(k['public_key']) for k in json.load(sys.stdin).get('keys',[])]" 2>/dev/null || true)
    if [ -n "$KEYS" ]; then
      echo "$KEYS" >> /root/.ssh/authorized_keys
    fi
    chmod 600 /root/.ssh/authorized_keys
    restorecon -r /root/.ssh 2>/dev/null || true
  USERDATA
}

# ═══════════════════════════════════════════════════════════════
# SOURCE BLOCKS
# ═══════════════════════════════════════════════════════════════

# ── us-south (primary) ───────────────────────────────────────────
source "ibmcloud-vpc" "rhel92_us_south" {
  api_key = var.ibm_api_key

  region    = "us-south"
  subnet_id = var.subnet_id_us_south

  resource_group_id = var.ibm_resource_group_id
  security_group_id = ""

  vsi_base_image_name = var.base_image_name
  vsi_profile         = "cx2-2x4"
  vsi_interface       = "public"
  ssh_key_type        = "rsa"

  # Inject the Packer-generated public key via user-data cloud-init.
  # This writes authorized_keys BEFORE sshd starts, bypassing the
  # IBM Cloud metadata key-injection timing issue on RHEL 9 minimal.
  vsi_user_data = local.cloud_init_user_data

  image_name = "${local.image_name}-us-south"

  communicator = "ssh"
  ssh_username = "root"
  ssh_port     = 22
  ssh_timeout  = "45m"

  timeout = "60m"
}

# ── eu-de (DR) ───────────────────────────────────────────────────
source "ibmcloud-vpc" "rhel92_eu_de" {
  api_key = var.ibm_api_key

  region    = "eu-de"
  subnet_id = var.subnet_id_eu_de != "" ? var.subnet_id_eu_de : var.subnet_id_us_south

  resource_group_id = var.ibm_resource_group_id
  security_group_id = ""

  vsi_base_image_name = var.base_image_name
  vsi_profile         = "cx2-2x4"
  vsi_interface       = "public"
  ssh_key_type        = "rsa"
  vsi_user_data       = local.cloud_init_user_data

  image_name = "${local.image_name}-eu-de"

  communicator = "ssh"
  ssh_username = "root"
  ssh_port     = 22
  ssh_timeout  = "45m"

  timeout = "60m"
}

# ═══════════════════════════════════════════════════════════════
# BUILD BLOCK
# Set build_eu_de = false in student.pkrvars.hcl to skip eu-de.
# ═══════════════════════════════════════════════════════════════
build {
  name = "rhel92-golden"

  # Include eu-de source only when build_eu_de = true
  sources = var.build_eu_de ? [
    "source.ibmcloud-vpc.rhel92_us_south",
    "source.ibmcloud-vpc.rhel92_eu_de",
  ] : [
    "source.ibmcloud-vpc.rhel92_us_south",
  ]

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
      "rm -f /etc/ssh/ssh_host_*",
      "dnf clean all",
      "rm -rf /var/tmp/*",
      "truncate -s 0 /root/.bash_history",
      "sync",
    ]
  }

  # ── Post-processor: local manifest ──────────────────────────
  post-processor "manifest" {
    output     = "${path.root}/packer-manifest.json"
    strip_path = true
  }
}
