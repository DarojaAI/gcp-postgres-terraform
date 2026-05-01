# CLAUDE.md — gcp-postgres-terraform

## Terraform Rules (NON-NEGOTIABLE)

**Before every commit touching `*.tf` files:**

1. `terraform fmt -check -diff` — fix all formatting
2. `terraform init -backend=false` — verify syntax and variable references
3. `terraform validate` — verify all module references and outputs
4. `grep -rn 'backend "' .` — confirm ZERO backend blocks exist anywhere in the module (root or nested)

**Module constraint:** This repo is consumed as a git module. A module MUST NOT have a `backend` block. Backend is always provided by the consuming root module.

**Before tagging a new release:**
1. Verify steps above pass
2. Run `terraform init -backend=false` on a clean checkout of the tag
3. Tag semantically: `git tag -a v1.x -m "description"`
4. Push: `git push origin main && git push origin v1.x`
5. Update consuming repos to new ref

## Repository Structure

This repo follows the [HashiCorp standard module structure](https://developer.hashicorp.com/terraform/language/modules/develop/structure):
the root wraps a nested implementation so consumers can `source = "github.com/.../gcp-postgres-terraform?ref=v1.x"`.

```
gcp-postgres-terraform/
├── main.tf                 ← root wrapper: calls ./terraform and re-exports outputs
├── variables.tf            ← root variables (re-declared from nested)
├── versions.tf             ← provider version constraints
├── VERSION                 ← managed by Release Please
└── terraform/              ← nested implementation
    ├── postgres_module.tf  ← actual provisioning logic (compute, IAM, GCS, secrets)
    ├── variables.tf
    ├── outputs.tf
    ├── versions.tf
    ├── dev.tfvars / prod.tfvars
    ├── scripts/postgres_init.sh
    └── backend.tf.example  ← rename to backend.tf for local dev only
```

## Key Variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `project_id` | Yes | — | GCP project |
| `instance_name` | Yes | — | PostgreSQL instance name (validated regex) |
| `vpc_name` | Yes | — | Existing VPC network name |
| `network_id` | Yes | — | Full VPC resource ID (required to avoid `count` non-determinism — see commit c78b1ba) |
| `subnet_id` | Yes | — | Full subnet resource ID (same reason as `network_id`) |
| `postgres_db_password` | Yes | — | DB password (sensitive) |
| `pgvector_enabled` | No | `true` | Enable pgvector extension |
| `enable_backups` | No | `true` | Daily backups to GCS |
| `github_actions_backup_reader_sa` | No | `""` | GHA deploy SA email needing read access to the backup bucket |

**Note:** `github_actions_enabled` / `github_repo` appear in `*.tfvars` but are **not** module variables — there are no WIF resources in this repo. WIF is configured in the consuming root module (see [docs/CI-CD-SETUP.md](./docs/CI-CD-SETUP.md)).

## CI/CD Setup

**See [docs/CI-CD-SETUP.md](./docs/CI-CD-SETUP.md)** — required CI/CD steps for any repo
using this module with GitHub Actions + WIF. Covers project-level IAM (Step 1),
module configuration with `github_actions_backup_reader_sa` (Step 2), bucket-level
IAM bootstrap (Step 3), and terraform plan/apply (Step 4).

## CI Workflows (`.github/workflows/`)

| Workflow | Trigger | Purpose |
|---|---|---|
| `pre-commit.yml` | PR | Runs pre-commit hooks (fmt, validate, etc.) |
| `terraform-plan.yml` | manual | Terraform plan (disabled on PRs — see commit 9ecd9d0) |
| `terraform-apply.yml` | manual | Terraform apply |
| `release-please.yml` | push to main | Release Please version PRs and tags |
| `deploy-production.yml` | manual | Production deployment |
| `validate-deployment.yml` | post-deploy | Smoke-test deployed instance |

## Release Process

This project uses **Release Please** for automated semantic versioning based on conventional commits.

### Conventional Commits

Use these commit types to trigger version bumps:

| Commit Type | Release Type | Example |
|-------------|--------------|---------|
| `fix:` | patch (1.29.0 → 1.29.1) | `fix: resolve connection timeout issue` |
| `feat:` | minor (1.29.0 → 1.30.0) | `feat: add support for backup restoration` |
| `feat!:` or `BREAKING CHANGE:` | major (1.29.0 → 2.0.0) | `feat!: change variable name from db_name to instance_name` |
| `docs:`, `chore:`, `refactor:` | no release | `docs: update README with new examples` |

### How It Works

1. **Push to main/master** → Release Please analyzes commits and creates a PR with version changes
2. **Merge the PR** → Release Please creates a `v{major}.{minor}.{patch}` tag
3. **Tag push** → GitHub Release is automatically created with changelog

### Check Current Version

```bash
cat VERSION
# or
git describe --tags --abbrev=0
```