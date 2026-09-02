# ---------------------------------------------------------------
# packer/hcp-bucket-init.pkr.hcl
#
# PURPOSE: Creates the 'rhel92-golden' bucket in HCP Packer.
#
# The HCP Packer REST API does not expose a bucket-creation endpoint.
# Buckets are created automatically when Packer runs a build that
# includes an hcp_packer_registry block — this file uses the built-in
# null builder (zero cost, runs locally in <5 seconds) purely to
# trigger that bucket-creation flow.
#
# Run ONCE before the first real packer build:
#   export HCP_CLIENT_ID=...
#   export HCP_CLIENT_SECRET=...
#   packer build packer/hcp-bucket-init.pkr.hcl
#
# After this runs, the bucket exists and hcp-backfill-registration.sh
# can register the real IBM Cloud image artifacts into it.
# ---------------------------------------------------------------

packer {
  required_version = ">= 1.10.0"
}

# ── HCP Packer Registry block ────────────────────────────────
# This is what creates the bucket. Packer calls the internal gRPC
# endpoint that the REST API doesn't expose.
hcp_packer_registry {
  bucket_name = "rhel92-golden"
  description = "LAB-3931 — Hardened RHEL 9.8 golden images (us-south + eu-de)"

  bucket_labels = {
    "lab"            = "lab3931"
    "os"             = "rhel-9.8"
    "pipeline-stage" = "golden-image"
    "cis-benchmark"  = "rhel9-level-1"
    "owner"          = "itz-enablement-132"
  }

  build_labels = {
    "created-by" = "hcp-bucket-init"
    "purpose"    = "bucket-creation-only"
  }
}

# ── Null build — runs locally, zero cost ─────────────────────
source "null" "bucket_init" {
  communicator = "none"
}

build {
  name    = "hcp-bucket-init"
  sources = ["source.null.bucket_init"]

  # No provisioners needed — hcp_packer_registry block does all the work
  provisioner "shell-local" {
    inline = [
      "echo '[hcp-bucket-init] Bucket rhel92-golden created/verified in HCP Packer'",
      "echo '[hcp-bucket-init] Run hcp-backfill-registration.sh to register IBM Cloud artifacts'"
    ]
  }
}
