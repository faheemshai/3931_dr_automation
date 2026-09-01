terraform {
  required_version = ">= 1.6.0"

  required_providers {
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = "~> 1.65"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.2"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    hcp = {
      source  = "hashicorp/hcp"
      version = "~> 0.80"
    }
  }

  # ── Terraform Enterprise remote backend ─────────────────────────
  # Dynamic Credentials (Workload Identity) are configured in the
  # TFE workspace environment variables — no static tokens required.
  # See: https://developer.hashicorp.com/terraform/cloud-docs/workspaces/dynamic-provider-credentials
  cloud {
    organization = "eelab-automation" # ← replace with your TFE organisation
    workspaces {
      name = "tf_vault_demo" # ← replace with your workspace name
    }
  }
}
