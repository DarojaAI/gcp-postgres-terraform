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

  attribute_mapping = {
    "google.subject"             = "repo"
    "attribute.repository"       = "repository"
    "attribute.repository_owner" = "repository_owner"
    "attribute.workflow"         = "workflow"
    "attribute.ref"              = "ref"
    "attribute.sha"              = "sha"
    "attribute.actor"            = "actor"
    "attribute.environment"      = "environment"
  }

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# -----------------------------------------------------------------------------
# Service Account for GitHub Actions
# -----------------------------------------------------------------------------
resource "google_service_account" "github_actions" {
  count        = var.github_actions_enabled ? 1 : 0
  project      = var.project_id
  account_id   = "github-actions-deploy"
  display_name = "GitHub Actions - Terraform + Cloud Run Deploy"
  description  = "Service account used by GitHub Actions for CI/CD operations"
}

resource "google_service_account_iam_member" "github_actions_wif_binding" {
  count              = var.github_actions_enabled ? 1 : 0
  service_account_id = google_service_account.github_actions[0].name
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
  member  = "serviceAccount:${google_service_account.github_actions[0].email}"
}

resource "google_project_iam_member" "github_actions_cloud_run" {
  count   = var.github_actions_enabled ? 1 : 0
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_service_account.github_actions[0].email}"
}

resource "google_project_iam_member" "github_actions_secrets" {
  count   = var.github_actions_enabled ? 1 : 0
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.github_actions[0].email}"
}

resource "google_project_iam_member" "github_actions_artifact_registry" {
  count   = var.github_actions_enabled ? 1 : 0
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.github_actions[0].email}"
}

resource "google_project_iam_member" "github_actions_compute" {
  count   = var.github_actions_enabled ? 1 : 0
  project = var.project_id
  role    = "roles/compute.instanceAdmin.v1"
  member  = "serviceAccount:${google_service_account.github_actions[0].email}"
}

resource "google_project_iam_member" "github_actions_storage" {
  count   = var.github_actions_enabled ? 1 : 0
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.github_actions[0].email}"
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------
output "wif_provider" {
  description = "Full WIF provider resource name. Add this as WIF_PROVIDER in GitHub Actions variables."
  value       = google_iam_workload_identity_pool_provider.github_provider[0].name
}

output "wif_service_account" {
  description = "GitHub Actions SA email. Add this as WIF_SERVICE_ACCOUNT in GitHub Actions variables."
  value       = google_service_account.github_actions[0].email
}
