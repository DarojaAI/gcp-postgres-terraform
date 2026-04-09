# gcp-postgres-terraform

> **Status:** Stable — v1.10

PostgreSQL provisioning for GCP Compute Engine — extracted from [dev-nexus](https://github.com/patelmm79/dev-nexus).

**Latest:** `?ref=v1.10` — contains all fixes for project scoping, monitoring dashboard, and templatefile variable passing.

---

## Features

- **PostgreSQL on GCP Compute Engine** (not Cloud SQL) with configurable version (14/15/16)
- **pgvector extension** for vector similarity search
- **Persistent data disk** that survives VM recreation
- **VPC isolation** with private subnet
- **Cloud NAT** for outbound internet access
- **VPC Access Connector** for Cloud Run integration
- **Automated backups** to GCS (daily cron, 30-day retention + 3 versioned versions)
- **Disk snapshots** for disaster recovery (daily at 2am UTC)
- **Cloud Monitoring** dashboards and disk usage alerts
- **Secret Manager** integration for credentials (password, user, db name, host)
- **Schema injection** at provisioning time via `init_sql`

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         GCP                                 │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              VPC (custom name or pg-{name}-vpc)    │   │
│  │  ┌─────────────────────────────────────────────┐   │   │
│  │  │  Subnet (configurable CIDR, e.g. 10.8.0.0/24)│   │
│  │  │  ┌─────────────────────────────────────┐   │   │   │
│  │  │  │  PostgreSQL VM (e2-micro default)    │   │   │   │
│  │  │  │  - Ubuntu 22.04                      │   │   │   │
│  │  │  │  - PostgreSQL 15 + pgvector          │   │   │   │
│  │  │  │  - Persistent Data Disk (pd-standard)  │   │   │   │
│  │  │  └─────────────────────────────────────┘   │   │   │
│  │  └─────────────────────────────────────────────┘   │   │
│  │                                                      │   │
│  │  ┌──────────────────┐  ┌──────────────────────┐   │   │
│  │  │  VPC Connector    │  │  Cloud NAT (optional)  │   │   │
│  │  │  (10.8.1.0/28)   │  │  (outbound internet)   │   │   │
│  │  └──────────────────┘  └──────────────────────┘   │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │ Cloud Storage│  │ Secret Manager│  │ Cloud Monitor │   │
│  │ (backups)    │  │ (credentials) │  │ (dashboards)  │   │
│  └──────────────┘  └──────────────┘  └──────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---


---

## Using as a Git Module

This repo is designed to be consumed as a Terraform git module. Any service repo
can import the PostgreSQL provisioning by calling it with a git source URL:

```hcl
module "postgres" {
  source = "github.com/patelmm79/gcp-postgres-terraform//terraform?ref=v1.11"

  # Required
  project_id              = "your-gcp-project"
  postgres_db_password    = "your-password"

  # Optional — all have defaults
  instance_name           = "rag-pg"
  postgres_version        = "15"
  machine_type            = "e2-small"
  postgres_db_name        = "rag_taxonomy"
  pgvector_enabled        = true
  github_actions_enabled  = true
  github_repo            = "your-org/your-repo"
}
```

### Integration Pattern

```
your-service-repo/
├── deploy/terraform/          ← your deployment terraform
│   ├── main.tf               ← calls gcp-postgres-terraform as git module
│   ├── backend.tf            ← GCS remote state (see create-bucket.sh)
│   ├── variables.tf           ← your variables
│   ├── terraform.tfvars      ← your secrets (NOT committed)
│   └── schemas/              ← your SQL schemas (loaded via init_sql)
│       └── your_schema.sql
└── .github/workflows/        ← your CI/CD

gcp-postgres-terraform/       ← source of truth, maintained separately
└── terraform/               ← the module
```

### When to Update the Module Ref

Bump `?ref=vX.X` when:
- You want a bug fix or new feature from gcp-postgres-terraform
- The module interface changes (new variables, new outputs)
- Security updates to the PostgreSQL setup

Do NOT update when:
- Only your service-specific deployment config changes (vars, tfvars, workflows)
- Only your application code changes

### Tag Version Policy

Tags follow semver (`v1.0`, `v1.11`, `v2.0`). Each tag is a commit on `main`.
Check available versions:

```bash
git ls-remote --tags https://github.com/patelmm79/gcp-postgres-terraform.git
```

### GitHub Actions WIF

When `github_actions_enabled = true`, the module creates:
- Workload Identity Pool + Provider
- GitHub Actions service account
- IAM roles (editor, run.admin, secretmanager.secretAccessor, etc.)

After running `terraform apply`, copy outputs to your service repo's GitHub Actions variables:
- `WIF_PROVIDER` = `terraform output wif_provider`
- `WIF_SERVICE_ACCOUNT` = `terraform output wif_service_account`

See [SETUP.md](deploy/terraform/SETUP.md) in a consuming repo for the full workflow.

### Schema Injection

To inject a custom SQL schema on first boot, pass it via `init_sql`:

```hcl
module "postgres" {
  source = "github.com/patelmm79/gcp-postgres-terraform//terraform?ref=v1.11"
  # ...
  init_sql = file("${path.module}/schemas/your_schema.sql")
}
```

The `init_sql` is executed as `psql postgres postgres` on the VM's first startup.

---


## Repository Structure

```
gcp-postgres-terraform/
├── terraform/
│   ├── versions.tf              # Terraform + provider requirements
│   ├── variables.tf            # All configurable variables
│   ├── postgres_module.tf      # Core PostgreSQL provisioning
│   ├── outputs.tf              # Connection info, IPs, secrets, etc.
│   └── scripts/
│       ├── postgres_init.sh    # VM startup script (runs on first boot)
│       └── backup.sh           # Backup cron script
├── schema/
│   └── init.sql                # Base schema (pgvector + minimal)
├── README.md                   # This file
└── LICENSE
```

---

# Quick Start

## Prerequisites

- GCP project with billing enabled
- `gcloud` authenticated: `gcloud auth application-default login`
- Terraform 1.5+: `terraform --version`

## 1. Add to your terraform

```hcl
# postgres.tf
module "postgres" {
  source = "github.com/patelmm79/gcp-postgres-terraform//terraform?ref=v1.10"

  project_id              = var.project_id
  instance_name           = "my-app-db"
  postgres_db_name        = "myapp"
  postgres_db_user        = "myapp_user"
  postgres_db_password    = var.postgres_db_password   # Store in Secret Manager for production

  postgres_version       = "15"
  machine_type           = "e2-micro"    # FREE tier eligible
  disk_size_gb           = 30             # FREE tier eligible

  region                 = "us-central1"
  zone                   = "us-central1-b"
  subnet_cidr            = "10.8.0.0/24"

  pgvector_enabled       = true

  # Inject your app schema at provision time
  init_sql = file("${path.module}/../schemas/myapp.sql")
}
```

## 2. Initialize

```bash
# Create the GCS bucket for state (one-time)
gcloud storage buckets create "gs://my-app-terraform-state-${PROJECT_ID}" --location=us-central1

# Add backend.tf
cat > backend.tf << 'EOF'
terraform {
  backend "gcs" {
    bucket = "my-app-terraform-state-YOUR_PROJECT_ID"
    prefix = "my-app/postgres"
  }
}
EOF

terraform init
terraform plan
terraform apply
```

## 3. Connect your app

```hcl
# In your Cloud Run terraform:
env {
  name  = "DB_HOST"
  value = module.postgres.internal_ip
}
env {
  name  = "DB_PASSWORD"
  value = "my-app-db_POSTGRES_PASSWORD"   # Secret Manager name, not the secret value
}
env {
  name  = "VPC_CONNECTOR"
  value = module.postgres.vpc_connector_name
}
```

---

# Required Variables

| Variable | Type | Required | Description |
|----------|------|----------|-------------|
| `project_id` | string | **Yes** | GCP project ID. Must be passed explicitly — all GCP resources need it. |
| `instance_name` | string | **Yes** | Unique name for this DB instance (lowercase, hyphens only). Used as prefix for all resource names. |
| `postgres_db_password` | string | **Yes** | PostgreSQL password. Store in Secret Manager in production. |
| `postgres_db_name` | string | No | Database name. Default: `"postgres"` |
| `postgres_db_user` | string | No | Database user. Default: `"postgres"` |
| `postgres_version` | string | No | PostgreSQL version. Default: `"15"`. Options: `"14"`, `"15"`, `"16"` |
| `region` | string | No | GCP region. Default: `"us-central1"` |
| `zone` | string | No | GCP zone. Default: `"us-central1-b"` |
| `machine_type` | string | No | VM machine type. Default: `"e2-micro"` (free-tier eligible) |
| `disk_size_gb` | number | No | Data disk size in GB. Default: `30` (free-tier eligible) |
| `disk_type` | string | No | Disk type. Default: `"pd-standard"` |
| `subnet_cidr` | string | No | Subnet CIDR. Default: `"10.8.0.0/24"` |
| `pgvector_enabled` | bool | No | Enable pgvector extension. Default: `true` |
| `init_sql` | string | No | SQL schema to inject at provision time. Default: `""` |
| `assign_external_ip` | bool | No | Give VM a public IP. Default: `false` (use Cloud NAT instead) |
| `enable_cloud_nat` | bool | No | Enable Cloud NAT for outbound internet. Default: `true` |
| `enable_monitoring` | bool | No | Create monitoring dashboard and alerts. Default: `true` |
| `enable_oslogin` | bool | No | Enable OS Login for SSH. Default: `true` |
| `max_connections` | number | No | Max PostgreSQL connections. Default: `100` |
| `shared_buffers` | string | No | PostgreSQL shared_buffers. Default: `"256MB"` |
| `work_mem` | string | No | PostgreSQL work_mem. Default: `"4MB"` |
| `maintenance_work_mem` | string | No | PostgreSQL maintenance_work_mem. Default: `"64MB"` |

---

# Module Outputs

| Output | Description |
|--------|-------------|
| `internal_ip` | PostgreSQL host IP (use as `DB_HOST` for Cloud Run in same VPC) |
| `vpc_connector_name` | VPC Access Connector name — set as `VPC_CONNECTOR` env var on Cloud Run |
| `connection_string_internal` | Full connection string (password redacted) |
| `psql_command_internal` | Ready-to-use psql command for the VM |
| `secrets` | Map of Secret Manager secret IDs: `password`, `user`, `db`, `host` |
| `service_account_email` | VM service account email |
| `backup_bucket_name` | GCS bucket name for automated backups |
| `postgres_vm_name` | Compute Engine instance name |
| `network_name` | VPC network name |
| `subnet_name` | Subnet name |

---

# State File Separation (Critical)

**Always use separate GCS backend prefixes** for postgres vs. your app's Cloud Run/terraform state. Mixing states causes resources to be destroyed when the wrong terraform run applies.

Recommended prefix structure:

| Scope | Prefix |
|-------|--------|
| PostgreSQL | `my-app/postgres` |
| Cloud Run / App | `my-app/cloudrun` |

```hcl
# PostgreSQL terraform (deploy/terraform/):
terraform {
  backend "gcs" {
    bucket = "my-app-terraform-state"
    prefix = "my-app/postgres"
  }
}
```

```hcl
# App terraform (terraform/):
terraform {
  backend "gcs" {
    bucket = "my-app-terraform-state"
    prefix = "my-app/cloudrun"
  }
}
```

---

# Versioning & Updates

```bash
# Check available versions
git ls-remote --tags https://github.com/patelmm79/gcp-postgres-terraform

# Update to new version
# In your postgres.tf, change ?ref=v1.X  →  ?ref=v1.Y

# Pull and apply
terraform init -upgrade
terraform plan
terraform apply
```

**Always pin to a version tag (`?ref=v1.X`)** — never `?ref=main`. Branch history is mutable and can break your infrastructure silently.

---

# Troubleshooting

## "project: required field is not set"

**Cause:** `project_id` was not passed to the module, or a GCP resource in the module is missing `project = var.project_id`.

**Fix:** Ensure `project_id = var.project_id` is set in the module call. If the error persists after confirming the variable is set, the module itself may have a bug — check the [changelog](#changelog) and update to the latest version.

## "Invalid value for vars parameter: does not contain key XXX"

**Cause:** A shell variable in `postgres_init.sh` uses `${XXX}` syntax but `XXX` is not in the Terraform `templatefile()` vars map. Terraform interprets `${...}` as a template expression.

**Fix:** All shell variables used in the startup script must be passed via the `templatefile()` call in `postgres_module.tf`. See [Changelog v1.10](#changelog).

## "mosaicLayout: contains overlapping tiles"

**Cause:** Monitoring dashboard tiles don't have explicit `xPos`/`yPos`, causing Google Cloud to reject the dashboard as invalid.

**Fix:** v1.9+ sets explicit positions on all dashboard tiles. Update to latest version.

## "Redundant empty provider block"

**Cause:** The module's `versions.tf` previously contained empty `provider "google" {}` blocks. These are deprecated in Terraform 1.6+.

**Fix:** v1.4+ removed the empty provider blocks. Update to latest version.

## Terraform plan tries to destroy Cloud Run resources

**Cause:** The postgres terraform state (`prefix=my-app/postgres`) contains Cloud Run resources from a previous consolidated setup. State was not properly separated.

**Fix:** Clear the postgres state and re-apply:
```bash
# WARNING: This destroys all postgres resources. Backup data first.
gcloud storage rm "gs://my-bucket/my-app/postgres/default.tfstate"
terraform apply  # Will recreate with clean state
```

## Module cache has old version after update

**Cause:** Terraform caches modules locally. A `terraform init` does not always fetch new versions.

**Fix:** Clear the module cache before re-initing:
```bash
Remove-Item -Path ".terraform\modules\postgres" -Recurse -Force   # Windows
rm -rf .terraform/modules/postgres                                      # Linux/Mac
terraform init -upgrade
```

---

# Changelog

## v1.10 — Templatefile variable case fix
- `postgres_init.sh` now uses lowercase `${retry_delay}` consistently (matches the vars map passed by Terraform `templatefile()`)
- Shell variables that Terraform should fill must be lowercase in the script

## v1.9 — Monitoring dashboard tile positions
- Dashboard tiles now have explicit `xPos`/`yPos` to prevent "overlapping tiles" Google API error

## v1.8 — Duplicate project attribute removed
- `google_compute_router` and `google_compute_router_nat` had duplicate `project` entries (scripting error in v1.6)

## v1.7 — Additional project-scope fixes
- `google_compute_disk_resource_policy_attachment`: added `project = var.project_id`
- `google_monitoring_alert_policy`: added `project = var.project_id`

## v1.6 — Router project attribute
- `google_compute_router`: added `project = var.project_id`
- `google_compute_router_nat`: added `project = var.project_id`

## v1.5 — Network and snapshot region fixes
- `google_compute_network`: added `project = var.project_id`
- `google_compute_resource_policy`: added `project = var.project_id` and `region = var.region`

## v1.4 — Major project-scope fix (breaking change for module authors)
- Added `project = var.project_id` to **all** project-scoped GCP resources:
  - `google_project_service` (compute, servicenetworking, vpcaccess, secretmanager)
  - `google_compute_subnetwork`, `google_compute_firewall` (all 3)
  - `google_vpc_access_connector`, `google_storage_bucket`
  - `google_compute_disk`, `google_compute_address` (both)
  - `google_compute_instance`
  - `google_service_account`
  - `google_secret_manager_secret` (all 4)
- Removed empty provider block from `versions.tf` (deprecated in Terraform 1.6+)

## v1.0–v1.3 — Initial releases
- See git history for details

---

# Cost

| Resource | Configuration | Est. Monthly |
|----------|---------------|--------------|
| Compute Engine | e2-micro (us-central1) | ~$7 |
| Persistent Disk | 30GB pd-standard | ~$2 |
| Cloud NAT | ~1GB egress | ~$1 |
| Secret Manager | 5 secrets | ~$0.15 |
| Cloud Storage | 30GB backups | ~$1.50 |
| **Total** | | **~$12/mo** |

With always-free tier (e2-micro + 30GB disk + Cloud NAT): ~$0-3/mo in practice.

---

# License

MIT
