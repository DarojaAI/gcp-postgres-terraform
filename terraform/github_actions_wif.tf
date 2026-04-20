# =============================================================================
# GitHub Actions Workload Identity Federation
# =============================================================================
# Enables GitHub Actions to authenticate to GCP without storing credentials.
# Uses Workload Identity Federation (WIF) — no service account keys on disk.
#
# How it works:
#   GitHub Actions → OIDC token → WIF pool → Service Account
#
# Required GitHub Actions variables (Settings → Variables → Actions):
#   WIF_PROVIDER        = projects/<project>/locations/global/workloadIdentityPools/github-pool/providers/github-provider
#   WIF_SERVICE_ACCOUNT = github-actions-deploy@<project>.iam.gserviceaccount.com
#
# Required GitHub Actions secrets:
#   PROD_POSTGRES_PASSWORD = <your chosen database password>
#
# To enable: set github_actions_enabled = true in your .tfvars (default: true)
# =============================================================================

# -----------------------------------------------------------------------------
# Workload Identity Pool
# -----------------------------------------------------------------------------
resource "google_iam_workload_identity_pool" "github_pool" {
  count                     = var.github_actions_enabled ? 1 : 0
  project                   = var.project_id
  workload_identity_pool_id = "github-pool"
  display_name              = "GitHub Actions Pool"
  description               = "Workload Identity Pool for GitHub Actions CI/CD"
}

resource "google_iam_workload_identity_pool_provider" "github_provider" {
  count                              = var.github_actions_enabled ? 1 : 0
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_pool[0].workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub Actions Provider"
  description                        = "Authenticates GitHub Actions runs from ${var.github_owner}/${var.github_repo}"

  # Only map google.subject — other attribute mappings cause GCP provider to
  # auto-generate a CEL attribute_condition with bare claim names (no 'attribute.' prefix),
  # which fails validation. GitHub OIDC token contains: sub, repository, actor, etc.
  attribute_mapping = {
    "google.subject" = "sub"
  }

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  # Explicitly set to empty string to suppress GCP's auto-generated attribute_condition,
  # which would otherwise reference unmapped claims (e.g. attribute.repository) and fail
  # validation. Access is restricted by the IAM binding on the service account
  # (principalSet://iam.googleapis.com/.../attribute.repository/<repo>), not the provider.
  attribute_condition = ""
}

# -----------------------------------------------------------------------------
# Service Account for GitHub Actions
# Uses data source to detect existing SA — if found, uses it without creating.
# This makes the module idempotent when the SA already exists (e.g., shared project).
# -----------------------------------------------------------------------------

# Try to read existing SA — if it doesn't exist, data source returns empty
data "google_service_account" "github_actions" {
  count      = var.github_actions_enabled ? 1 : 0
  project    = var.project_id
  account_id = "github-actions-deploy"
}

# Create SA only if data source found nothing (SA doesn't exist yet)
resource "google_service_account" "github_actions" {
  count        = var.github_actions_enabled && length(data.google_service_account.github_actions[*].id) == 0 ? 1 : 0
  project      = var.project_id
  account_id   = "github-actions-deploy"
  display_name = "GitHub Actions - Terraform + Cloud Run Deploy"
  description  = "Service account used by GitHub Actions for CI/CD operations"
}

# SA to use: existing (data source) OR newly created
locals {
  sa_email = var.github_actions_enabled ? (
    length(google_service_account.github_actions[*].email) > 0
    ? google_service_account.github_actions[0].email
    : data.google_service_account.github_actions[0].email
  ) : ""
  # Full resource name for iam_member bindings (email alone doesn't work for iam_member)
  sa_resource_name = "projects/${var.project_id}/serviceAccounts/${local.sa_email}"
}

resource "google_service_account_iam_member" "github_actions_wif_binding" {
  count              = var.github_actions_enabled ? 1 : 0
  service_account_id = local.sa_resource_name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_pool[0].name}/attribute.repository/${var.github_repo}"
}

# -----------------------------------------------------------------------------
# IAM Roles for the GitHub Actions SA
# -----------------------------------------------------------------------------
resource "google_project_iam_member" "github_actions_editor" {
  count   = var.github_actions_enabled ? 1 : 0
  project = var.project_id
  role    = "roles/editor"
  member  = "serviceAccount:${local.sa_email}"
}

resource "google_project_iam_member" "github_actions_cloud_run" {
  count   = var.github_actions_enabled ? 1 : 0
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${local.sa_email}"
}

resource "google_project_iam_member" "github_actions_secrets" {
  count   = var.github_actions_enabled ? 1 : 0
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${local.sa_email}"
}

resource "google_project_iam_member" "github_actions_artifact_registry" {
  count   = var.github_actions_enabled ? 1 : 0
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${local.sa_email}"
}

resource "google_project_iam_member" "github_actions_compute" {
  count   = var.github_actions_enabled ? 1 : 0
  project = var.project_id
  role    = "roles/compute.instanceAdmin.v1"
  member  = "serviceAccount:${local.sa_email}"
}

resource "google_project_iam_member" "github_actions_storage" {
  count   = var.github_actions_enabled ? 1 : 0
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${local.sa_email}"
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------
output "wif_provider" {
  description = "Full WIF provider resource name. Add this as WIF_PROVIDER in GitHub Actions variables."
  value       = var.github_actions_enabled ? google_iam_workload_identity_pool_provider.github_provider[0].name : "disabled"
}

output "wif_service_account" {
  description = "GitHub Actions SA email. Add this as WIF_SERVICE_ACCOUNT in GitHub Actions variables."
  value       = local.sa_email
}
