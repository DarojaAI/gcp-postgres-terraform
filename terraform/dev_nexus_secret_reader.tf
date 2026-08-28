# =============================================================================
# IAM grant: dev-nexus SA read-grant on Secret Manager
# =============================================================================
# Purpose: dev-nexus runs two PR-time / cron checks against Secret Manager
#   - audit-secret-manager-rotation.py (DarojaAI/dev-nexus#1469):
#       reads `next_rotation_time`, `create_time`, version counts to detect drift.
#   - audit-secrets-schema.py (DarojaAI/dev-nexus#1468):
#       reads secret metadata to verify cross-repo contract surface.
#
# Why project-wide viewer (not per-secret):
#   - dev-nexus needs metadata only, not secret VALUES.
#   - Project-scoped = single resource; per-secret would be 12+ resources.
#   - Honors Q18 cross-product IAM grant pattern (MEMORY.md fact #13).
#
# Why `roles/secretmanager.viewer` (not `secretAccessor`):
#   - dev-nexus does NOT need to read secret values.
#   - `secretAccessor` would grant read access to plaintext secrets, broader than needed.
#
# Audit:
#   Each read by this SA emits a Secret Manager audit-log entry under
#   `projects/globalbiting-dev/logs/secret-manager-audit`. No additional logging needed.
# =============================================================================

# Conditional grant: only emit the IAM binding when `var.dev_nexus_secret_reader_sa`
# is set. Empty string disables the grant. This matches the existing
# `github_actions_backup_reader_sa` variable pattern in this module.
resource "google_project_iam_member" "dev_nexus_secret_viewer" {
  count = var.dev_nexus_secret_reader_sa != "" ? 1 : 0

  project = var.project_id
  role    = "roles/secretmanager.viewer"
  member  = "serviceAccount:${var.dev_nexus_secret_reader_sa}"
}
