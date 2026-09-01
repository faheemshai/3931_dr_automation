# ---------------------------------------------------------------
# packer/hcp-bucket-init.pkr.hcl
#
# ONE-TIME setup template — creates the rhel92-golden bucket in
# HCP Packer. Run this ONCE before the first IBM Cloud build.
#
# The IBM Cloud Packer plugin does not support hcp_packer_registry,
# so this template uses the built-in `null` builder (which is fully
# HCP-compatible) purely to trigger bucket creation.
#
# Prerequisites:
#   export HCP_CLIENT_ID=$(vault kv get -namespace=admin -mount=kv -field=client_id Packer)
#   export HCP_CLIENT_SECRET=$(vault kv get -namespace=admin -mount=kv -field=client_secret Packer)
#
# Usage (run once from the packer/ directory):
#   packer init hcp-bucket-init.pkr.hcl
#   packer build hcp-bucket-init.pkr.hcl
#
# After this runs:
#   - The rhel92-golden bucket appears in the HCP Packer portal
#   - Run hcp-register-build.sh to register existing IBM Cloud builds
#   - Future packer builds auto-register via the shell-local post-processor
# ---------------------------------------------------------------

packer {
  required_plugins {
    # null builder is built into Packer — no install needed
  }
}

# Register the bucket in HCP Packer
build {
  name = "rhel92-golden"

  hcp_packer_registry {
    bucket_name = "rhel92-golden"
    description = "Hardened RHEL 9.2 golden image for LAB-3931 DR automation"

    bucket_labels = {
      "lab"        = "lab-3931"
      "os"         = "rhel-9.2"
      "managed-by" = "packer"
    }

    build_labels = {
      "pipeline-stage" = "bucket-init"
    }
  }

  # null builder — does nothing on the machine, just satisfies Packer's
  # requirement for at least one source so hcp_packer_registry can run
  sources = ["source.null.placeholder"]

  # No provisioners needed — this build does nothing except register with HCP
}

source "null" "placeholder" {
  communicator = "none"
}
