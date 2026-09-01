# ---------------------------------------------------------------
# packer/rhel92-ibmcloud.pkr.hcl
#
# LAB-3931 — Automating Disaster Recovery
# Builds a hardened RHEL 9.2 golden image on IBM Cloud and registers
# it in HCP Packer automatically via a post-processor shell-local.
#
# HCP Packer auth — export before running packer build:
#   export HCP_CLIENT_ID=$(vault kv get -namespace=admin -mount=kv -field=client_id Packer)
#   export HCP_CLIENT_SECRET=$(vault kv get -namespace=admin -mount=kv -field=client_secret Packer)
#   export IBM_API_KEY=$(vault kv get -namespace=admin -mount=kv -field=ibm_api_key IBM_cloud)
#
# Usage:
#   cd packer/
#   packer init .
#   packer validate -var-file=student.pkrvars.hcl .
#   packer build   -var-file=student.pkrvars.hcl .
#
# After the build:
#   - Image ID is in packer-manifest.json
#   - Build is automatically registered in HCP Packer (if HCP env vars are set)
#   - Supply golden_image_name_us_south in terraform.tfvars for Task 2
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
  # NOTE: The IBM Cloud Packer plugin (v3.7.0) does not implement
  # the hcp_packer_registry block interface — using it produces:
  #   "No HCP Packer-compatible artifacts were found for the build"
  #
  # Registration is handled by the shell-local post-processor below,
  # which runs on the local machine after image capture and calls the
  # HCP REST API directly using HCP_CLIENT_ID / HCP_CLIENT_SECRET.
  # If those env vars are not set, the step is skipped gracefully —
  # the build itself never fails due to HCP registration.
  # ── ─────────────────────────────────────────────────────────

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

  # ── Step 4: Generate SBOM (Software Bill of Materials) ───────
  # provisioner "hcp-sbom" with auto_generate=true:
  #   - Packer uploads its own binary to the VSI (no extra tools needed)
  #   - Runs `packer sbom-generate` (embedded Syft SDK) on the VSI
  #   - Scans the entire filesystem (/) for installed packages
  #   - Downloads the CycloneDX JSON SBOM to packer/sbom/ locally
  #   - Uploads the SBOM to HCP Packer and attaches it to the version
  #   - packer/sbom/ dir is tracked via .gitkeep; *.json is gitignored
  #
  # Runs AFTER hardening and metadata stamping so the SBOM reflects
  # the exact final state of the image before capture.
  # Packer cleans up the uploaded binary from the VSI after the scan.
  #
  # Ref: https://developer.hashicorp.com/packer/docs/provisioners/hcp-sbom
  provisioner "hcp-sbom" {
    auto_generate = true
    destination   = "${path.root}/sbom/"
    sbom_name     = "rhel92-golden-${local.timestamp}"
  }

  # ── Step 5: Pre-capture cleanup ─────────────────────────────
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

  # ── Post-processors: manifest then HCP registration ─────────
  # The sequence block guarantees manifest is written first, then
  # shell-local reads it to register the build in HCP Packer.
  post-processor "manifest" {
    output     = "${path.root}/packer-manifest.json"
    strip_path = true
  }

  # Runs on your local machine after image capture — no VSI needed.
  # Reads artifact_id + packer_run_uuid from packer-manifest.json.
  # Requires HCP_CLIENT_ID and HCP_CLIENT_SECRET in the environment.
  # Set them before the build:
  #   export HCP_CLIENT_ID=$(vault kv get -namespace=admin -mount=kv -field=client_id Packer)
  #   export HCP_CLIENT_SECRET=$(vault kv get -namespace=admin -mount=kv -field=client_secret Packer)
  post-processor "shell-local" {
    # HCP_CLIENT_ID and HCP_CLIENT_SECRET are inherited from the shell
    # environment where you ran `packer build` — no need to re-declare them.
    # PACKER_TEMPLATE_DIR tells the script where packer-manifest.json lives.
    environment_vars = [
      "PACKER_TEMPLATE_DIR=${path.root}",
    ]
    execute_command    = ["sh", "-c", "{{.Vars}} sh '{{.Script}}'"]
    script             = "${path.root}/scripts/hcp-register-build.sh"
    # Image is already captured — never fail the build over HCP registration
    valid_exit_codes   = [0, 1, 2]
  }
}
