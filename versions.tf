terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.2"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Terraform Enterprise / HCP Terraform remote backend
  # Uncomment and fill in when running against TFE/TFC
  # cloud {
  #   organization = "my-org"
  #   workspaces {
  #     name = "prod-ec2-demo"
  #   }
  # }
}
