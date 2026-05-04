# Consuming gcp-postgres-terraform

This guide documents how to integrate the gcp-postgres-terraform module into your infrastructure as code.

## Module Overview

gcp-postgres-terraform creates a CloudSQL PostgreSQL instance with automatic backups, VPC integration, and Secret Manager integration for credentials.

## Required Inputs

These inputs must be provided to use this module:

| Input | Type | Description | Example |
|-------|------|-------------|---------|
| `project_id` | string | GCP project ID | `my-project-123` |
| `region` | string | GCP region | `us-central1` |
| `zone` | string | GCP zone | `us-central1-a` |
| `environment` | string | Deployment environment (dev/staging/prod) | `dev` |
| `repo_prefix` | string | Repository name prefix for resource naming | `rag-research-tool` |
| `network_id` | string | VPC network ID (resource ID) | `projects/PROJECT/global/networks/vpc-name` |
| `subnet_id` | string | VPC subnet ID (resource ID) | `projects/PROJECT/regions/REGION/subnetworks/subnet-name` |
| `subnet_cidr` | string | Subnet CIDR range for validation | `10.0.1.0/24` |
| `postgres_version` | string | PostgreSQL version | `POSTGRES_15` |
| `postgres_db_name` | string | Initial database name | `myapp_db` |
| `postgres_db_user` | string | Database user name | `postgres` |
| `postgres_db_password` | string | Database user password (sensitive) | (generated or provided) |

## Optional Inputs

These inputs have sensible defaults but can be customized:

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `machine_type` | string | `db-n1-standard-2` | CloudSQL machine type |
| `disk_size_gb` | number | `20` | Initial disk size in GB |
| `disk_type` | string | `PD_SSD` | Disk type (PD_SSD or PD_HDD) |
| `init_sql` | string | `""` | SQL script for database initialization |
| `assign_external_ip` | bool | `false` | Assign external IP address |
| `backup_location` | string | `us` | Cloud Storage bucket location for backups |

## Critical Outputs to Re-export

When consuming this module, **always re-export these outputs** to downstream modules and your root module:

### Secret Management (Most Important)

```hcl
output "postgres_secrets" {
  description = "PostgreSQL secret resource IDs (full paths for Secret Manager API)"
  value       = module.postgres.secrets
  sensitive   = true
}

output "postgres_secret_names" {
  description = "PostgreSQL secret names (bare names for gcloud CLI usage)"
  value       = module.postgres.secret_names
  # Not sensitive - these are just the secret names, not the actual secrets
}
```

**Usage Pattern:**
```bash
# Get a specific secret value using gcloud CLI
SECRET_NAME=$(terraform output -raw postgres_secret_names.password)
gcloud secrets versions access latest --secret="$SECRET_NAME"

# Or use in Cloud Run with Secret Manager bindings
gcloud run deploy myservice --set-secrets DATABASE_PASSWORD=$SECRET_NAME
```

### Network Access

```hcl
output "postgres_internal_ip" {
  description = "PostgreSQL internal IP address (use for services in same VPC)"
  value       = module.postgres.internal_ip
}

output "postgres_external_ip" {
  description = "PostgreSQL external IP address (only if assign_external_ip = true)"
  value       = module.postgres.external_ip
}
```

### Connection Information

```hcl
output "postgres_host" {
  description = "PostgreSQL host for connection strings"
  value       = module.postgres.internal_ip  # or external_ip if external access needed
}

output "postgres_port" {
  description = "PostgreSQL port (always 5432)"
  value       = module.postgres.port
}

output "postgres_db_name" {
  description = "Initial database name"
  value       = module.postgres.postgres_db_name
}

output "postgres_connection_string" {
  description = "Computed connection string (convenience output)"
  value       = "postgresql://${module.postgres.postgres_db_user}:****@${module.postgres.internal_ip}:${module.postgres.port}/${module.postgres.postgres_db_name}"
  sensitive   = true
}
```

## Common Pitfalls

### ❌ Mistake 1: Using Non-existent Secret Fields

**Wrong:**
```hcl
postgres_password_secret = module.postgres.secrets.user  # DOES NOT EXIST
postgres_password_secret = module.postgres.secrets.db    # DOES NOT EXIST
```

**Correct:**
```hcl
# Available secret names in module.postgres.secrets:
# - .username  (database user name)
# - .password  (database password)
# - .database  (database name)

postgres_password_secret = module.postgres.secrets.password
```

**Why:** The module creates secrets for username, password, and database name. Check module outputs to verify available secret names.

### ❌ Mistake 2: Hardcoding Port 5432

**Wrong:**
```hcl
postgres_port = "5432"  # Hardcoded - breaks if module changes default
```

**Correct:**
```hcl
postgres_port = module.postgres.port  # Always references module output
```

**Why:** Port is a module output. Always reference it to ensure consistency if the module changes.

### ❌ Mistake 3: Not Re-exporting secret_names

**Wrong:**
```hcl
# Root module outputs don't include secret_names
# gcloud CLI users must know internal module structure
terraform output postgres_secrets  # Gets resource IDs, not useful for gcloud
```

**Correct:**
```hcl
# Root module re-exports both formats
output "postgres_secret_names" {
  value = module.postgres.secret_names
}

# Now gcloud CLI users can do:
terraform output -raw postgres_secret_names.password | xargs -I {} \
  gcloud secrets versions access latest --secret="{}"
```

**Why:** gcloud CLI expects bare secret names, not resource IDs. Root module should expose both formats for different use cases.

### ❌ Mistake 4: Using External IP When VPC Available

**Wrong:**
```hcl
# GitHub Actions inside VPC should use internal IP
postgres_host = module.postgres.external_ip
```

**Correct:**
```hcl
# For services in same VPC, always use internal IP
postgres_host = module.postgres.internal_ip
# For external access (GitHub Actions from public runners), only then use external_ip
postgres_host = module.postgres.external_ip  # if assign_external_ip = true
```

**Why:** Internal IP is faster, more secure, and avoids external egress costs.

## Integration Example

See [rag-research-tool](https://github.com/DarojaAI/rag_research_tool/blob/main/deploy/terraform/main.tf) for a complete integration example showing:

- Module instantiation with required inputs
- Proper output re-exports
- Consumption by downstream modules (gcp-dbt-terraform)
- Secret usage patterns in GitHub Actions workflows

## Related Documentation

- [gcp-vpc-egress-terraform](https://github.com/DarojaAI/gcp-vpc-egress-terraform) — VPC and subnet creation (provides network_id, subnet_id, subnet_cidr)
- [gcp-dbt-terraform](https://github.com/DarojaAI/gcp-dbt-terraform) — dbt Cloud Run job that consumes postgres outputs
- [PostgreSQL Secrets Migration Guide](./docs/POSTGRES_SECRETS_MIGRATION.md) — Migrating from hardcoded secrets to Secret Manager
