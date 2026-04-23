# CLAUDE.md — gcp-postgres-terraform

## Terraform Rules (NON-NEGOTIABLE)

**Before every commit touching `*.tf` files:**

1. `terraform fmt -check -diff` — fix all formatting
2. `terraform init -backend=false` — verify syntax and variable references
3. `terraform validate` — verify all module references and outputs
4. `grep -rn 'backend "' *.tf` — confirm ZERO backend blocks exist in the module

**Module constraint:** This repo is consumed as a git module. A module MUST NOT have a `backend` block. Backend is always provided by the consuming root module.

**Before tagging a new release:**
1. Verify steps above pass
2. Run `terraform init -backend=false` on a clean checkout of the tag
3. Tag semantically: `git tag -a v1.x -m "description"`
4. Push: `git push origin main && git push origin v1.x`
5. Update consuming repos to new ref

## Repository Structure

```
gcp-postgres-terraform/
└── terraform/              ← THE MODULE (used as: ?ref=v1.x)
    ├── main.tf            ← module call block (NO backend)
    ├── variables.tf
    ├── outputs.tf
    ├── versions.tf
    ├── postgres_module.tf ← actual provisioning logic
    ├── github_actions_wif.tf
    ├── scripts/
    │   └── postgres_init.sh
    └── backend.tf.example ← rename to backend.tf for local dev
```

## Key Variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `project_id` | Yes | — | GCP project |
| `postgres_db_password` | Yes | — | DB password |
| `pgvector_enabled` | No | `true` | Enable pgvector extension |
| `github_actions_enabled` | No | `true` | Create WIF for GitHub Actions |
| `github_repo` | No | `patelmm79/gcp-postgres-terraform` | GitHub repo |
## Post-Setup Steps (Required for GitHub Actions CI/CD)

When using this module with GitHub Actions + Workload Identity Federation, the SA needs
one-time bootstrap permissions that terraform plan requires BEFORE it can read bucket state.

### One-Time Bucket IAM Grant

After the first `terraform apply` creates the backup bucket, the GitHub Actions SA must be
granted `storage.objectViewer` on the bucket so terraform plan can read bucket IAM during
subsequent plan/apply cycles. This is a bootstrap chicken-and-egg issue.

**Find your bucket name** (matches pattern: `{repo_prefix}-{environment}-postgres-backups`):

```bash
# Example for repo_prefix=dev-nexus, environment=prod
BUCKET_NAME="dev-nexus-prod-postgres-backups"
SA_EMAIL="github-actions-deploy@${PROJECT_ID}.iam.gserviceaccount.com"

gcloud storage buckets add-iam-policy-binding "gs://${BUCKET_NAME}" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/storage.objectViewer"
```

**Why this is not in terraform:** Terraform plan needs to READ the bucket to reconcile
state — but if the SA doesn't have read permission, plan fails before apply can run.
The terraform resource `google_storage_bucket_iam_member.github_actions_backup_reader`
(optionally passed via `github_actions_backup_reader_sa` variable) handles ongoing
maintenance, but the very first plan needs the bootstrap grant above.

**Recommended:** Add this as a step in your consuming repo's WIF setup script, gated on
whether a backup bucket is in use (when `github_actions_backup_reader_sa` is passed).

