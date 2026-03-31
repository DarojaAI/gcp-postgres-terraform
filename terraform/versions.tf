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

# Provider configuration (project/region set via CLI or environment variables)
provider "google" {
  # project and region can be set via:
  # - environment variables: GCP_PROJECT_ID, GCP_REGION
  # - CLI flags: -var="project_id=..."
  # - terraform.tfvars file
}
