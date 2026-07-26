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
  }

  # Terraform Enterprise / HCP Terraform remote backend
  # Uncomment and fill in when running against TFE/TFC
  # cloud {
  #   organization = "my-org"
  #   workspaces {
  #     name = "prod-ibm-vsi-demo"
  #   }
  # }
}
