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

  # Human-readable build date for HCP Packer portal labels
  build_date = formatdate("YYYY-MM-DD", timestamp())

  # cloud-init user-data: fetch SSH keys from IBM Cloud metadata service
  # and write them to authorized_keys immediately at first boot.
  # This forces key injection before sshd starts — fixes the RHEL 9
  # minimal image timing race where cloud-init finishes too late.
  cloud_init_user_data = <<-USERDATA
    #!/bin/bash
    set -e
    mkdir -p /home/vpcuser/.ssh
    chmod 700 /home/vpcuser/.ssh
    # Fetch all SSH keys registered to this VSI from the metadata service
    KEYS=$(curl -sf -H "Metadata-Flavor: ibm" \
      "http://169.254.169.254/metadata/v1/keys?version=2022-03-01" \
      | python3 -c "import sys,json; [print(k['public_key']) for k in json.load(sys.stdin).get('keys',[])]" 2>/dev/null || true)
    if [ -n "$KEYS" ]; then
      echo "$KEYS" >> /home/vpcuser/.ssh/authorized_keys
    fi
    chmod 600 /home/vpcuser/.ssh/authorized_keys
    chown -R vpcuser:vpcuser /home/vpcuser/.ssh
    restorecon -r /home/vpcuser/.ssh 2>/dev/null || true
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
  ssh_username = "vpcuser"
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
  ssh_username = "vpcuser"
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

  # ── HCP Packer Registry ──────────────────────────────────────
  # Publishes version metadata to the HCP Packer portal so the
  # bucket shows Newest version, Published date, and Fingerprint.
  # Requires env vars at build time (never hard-coded):
  #   export HCP_CLIENT_ID="..."
  #   export HCP_CLIENT_SECRET="..."
  #   export HCP_ORGANIZATION_ID="..."   # from portal URL
  #   export HCP_PROJECT_ID="..."        # from portal URL
  hcp_packer_registry {
    bucket_name   = "rhel92-golden"
    description   = "Hardened RHEL 9.2 golden image for LAB-3931 DR pipeline"

    # bucket_labels appear on the bucket overview page (permanent tags)
    bucket_labels = {
      "lab"        = "lab-3931"
      "managed-by" = "packer"
      "os"         = "rhel-9.2"
      "base-image" = var.base_image_name
      "student-id" = var.student_id
    }

    # build_labels appear on EACH VERSION in the portal — this is where
    # the hardening evidence shows. Every key/value is visible in the
    # "Version details" tab and exportable as a data source in Terraform.
    build_labels = {
      # ── Identity ────────────────────────────────────────────
      "build-date"        = local.build_date
      "build-timestamp"   = local.timestamp
      "image-name"        = local.image_name

      # ── Hardening checklist ─────────────────────────────────
      # Each entry maps to a numbered step in harden-rhel92.sh
      "hardening-step-1"  = "system-packages-updated"
      "hardening-step-2"  = "nginx-jq-openssl-curl-installed"
      "hardening-step-3"  = "unnecessary-services-disabled"
      "hardening-step-4"  = "cis-sysctl-kernel-hardening-applied"
      "hardening-step-5"  = "selinux-set-to-enforcing"
      "hardening-step-6"  = "ssh-hardened-no-password-auth"
      "hardening-step-7"  = "firewalld-drop-zone-ssh-http-https-only"
      "hardening-step-8"  = "audit-chrony-rsyslog-enabled-at-boot"

      # ── Compliance alignment ─────────────────────────────────
      "cis-benchmark"     = "rhel9-level-1"
      "ssh-root-login"    = "without-password"
      "ipv6"              = "disabled"
      "selinux-policy"    = "targeted"
      "password-auth"     = "disabled"
      "x11-forwarding"    = "disabled"

      # ── DR pipeline context ──────────────────────────────────
      "dr-lab"            = "lab-3931"
      "primary-region"    = "us-south"
      "dr-region"         = "eu-de"
      "pipeline-stage"    = "golden-image"
    }
  }

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
    execute_command = "{{.Vars}} sudo -S bash '{{.Path}}'"
    inline = [
      "chmod +x /tmp/harden-rhel92.sh",
      "sudo /tmp/harden-rhel92.sh",
    ]
    timeout = "20m"
  }

  # ── Step 3: Stamp build metadata ────────────────────────────
  provisioner "shell" {
    execute_command = "{{.Vars}} sudo -S bash '{{.Path}}'"
    inline = [
      "sudo bash -c \"echo 'LAB_BUILD_IMAGE=${local.image_name}' >> /etc/os-release\"",
      "sudo bash -c \"echo 'LAB_BUILD_DATE=${local.timestamp}'   >> /etc/os-release\"",
      "sudo bash -c \"echo 'LAB_STUDENT_ID=${var.student_id}'    >> /etc/os-release\"",
    ]
  }

  # ── Step 4: Pre-capture cleanup ─────────────────────────────
  provisioner "shell" {
    execute_command = "{{.Vars}} sudo -S bash '{{.Path}}'"
    inline = [
      "sudo rm -f /etc/ssh/ssh_host_*",
      "sudo dnf clean all",
      "sudo rm -rf /var/tmp/*",
      "sudo truncate -s 0 /root/.bash_history",
      "sync",
    ]
  }

  # ── Post-processor: local manifest ──────────────────────────
  post-processor "manifest" {
    output     = "${path.root}/packer-manifest.json"
    strip_path = true
  }
}
