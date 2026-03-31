# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## What is gcp-postgres-terraform?

Standalone PostgreSQL provisioning for GCP Compute Engine — extracted from [dev-nexus](https://github.com/patelmm79/dev-nexus). Provides CLI, REST API, and MCP tools for provisioning and managing PostgreSQL instances on GCP.

## Current Status

**Phase 1 in progress.** Terraform is extracted and parameterized. Validating syntax before moving to CLI.

## Architecture

- Terraform module in `terraform/` provisions PostgreSQL on GCP Compute Engine
- `terraform/postgres_module.tf` — core provisioning (VPC, VM, disks, networking, IAM, backups)
- `terraform/scripts/postgres_init.sh` — VM startup script (PostgreSQL install, pgvector, schema injection)
- `schema/init.sql` — base schema (extend via `--init-sql` flag)

## Terraform Workflow

```bash
cd terraform

# Initialize
terraform init

# Validate (syntax check)
terraform validate

# Plan
terraform plan -var-file=terraform.tfvars

# Apply
terraform apply -var-file=terraform.tfvars

# Destroy
terraform destroy -var-file=terraform.tfvars
```

## Key Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `project_id` | Yes | - | GCP project ID |
| `instance_name` | Yes | - | Name for all resources (prefix) |
| `postgres_db_password` | Yes | - | Database password |
| `region` | No | us-central1 | GCP region |
| `postgres_version` | No | 15 | PostgreSQL 14/15/16 |
| `machine_type` | No | e2-micro | VM size |
| `pgvector_enabled` | No | true | Install pgvector |
| `init_sql` | No | "" | Custom SQL on startup |

## Important Rules

1. **All resource names auto-prefixed** from `instance_name` — no hardcoded "dev-nexus-*" names
2. **Passwords never in state output** — stored in Secret Manager
3. **Disk survives VM recreation** — data is on separate persistent disk
4. **Schema injection via `init_sql`** — not baked into startup script

## Future Phases

- Phase 2: CLI tool (Click)
- Phase 3: REST API (FastAPI)
- Phase 4: MCP Server (AI agent tools)
- Phase 5: Schema injection improvements
- Phase 6: Testing

## Related

- Original PostgreSQL provisioning: [dev-nexus/terraform/postgres.tf](https://github.com/patelmm79/dev-nexus/blob/main/terraform/postgres.tf)
- Full plan: [dev-nexus/docs/superpowers/plans/2026-03-31-gcp-postgres-terraform-extraction-plan.md](https://github.com/patelmm79/dev-nexus/blob/main/docs/superpowers/plans/2026-03-31-gcp-postgres-terraform-extraction-plan.md)
