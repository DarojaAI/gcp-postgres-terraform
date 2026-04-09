# Terraform Requirements

terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# Note: Provider is configured by the consuming module.
# The consuming application's main.tf should configure the Google provider.
