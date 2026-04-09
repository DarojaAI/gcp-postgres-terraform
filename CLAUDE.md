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
