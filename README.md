# gcp-postgres-terraform

> **Status:** In Progress - Phase 1 (Terraform Extraction)

Standalone PostgreSQL provisioning for GCP Compute Engine — extracted from [dev-nexus](https://github.com/patelmm79/dev-nexus).

**Why this exists:** PostgreSQL on Compute Engine with pgvector, not Cloud SQL — full control, free-tier eligible (e2-micro), and configurable via CLI, REST API, or MCP tools for AI agents.

---

## Features

- **PostgreSQL on GCP Compute Engine** (not Cloud SQL) with configurable version (14/15/16)
- **pgvector extension** for vector similarity search
- **Persistent data disk** that survives VM recreation
- **VPC isolation** with private subnet
- **Cloud NAT** for outbound internet access
- **VPC Access Connector** for Cloud Run integration
- **Automated backups** to GCS (daily cron)
- **Disk snapshots** for disaster recovery (daily at 2am UTC)
- **Cloud Monitoring** dashboards and alerts
- **Secret Manager** integration for credentials
- **Schema injection** at provisioning time

---

## Quick Start

### Prerequisites

- GCP project with billing enabled
- `gcloud` CLI authenticated (`gcloud auth application-default login`)
- Terraform 1.5+

### Install CLI (coming soon)

```bash
# Not yet built - see Phase 2
pip install gcp-postgres
```

### Provision via Terraform directly

```bash
cd terraform

# Copy and edit config
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Initialize
terraform init

# Preview
terraform plan

# Apply
terraform apply
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         GCP                                 │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              VPC (10.8.0.0/24)                      │   │
│  │  ┌─────────────────────────────────────────────┐   │   │
│  │  │  Subnet (10.8.0.0/24)                       │   │   │
│  │  │  ┌─────────────────────────────────────┐   │   │   │
│  │  │  │  PostgreSQL VM (e2-micro)           │   │   │   │
│  │  │  │  - Ubuntu 22.04                      │   │   │   │
│  │  │  │  - PostgreSQL 15 + pgvector          │   │   │   │
│  │  │  │  - Persistent Data Disk (pd-standard) │   │   │   │
│  │  │  └─────────────────────────────────────┘   │   │   │
│  │  └─────────────────────────────────────────────┘   │   │
│  │                                                      │   │
│  │  ┌──────────────────┐  ┌──────────────────────┐   │   │
│  │  │  VPC Connector    │  │  Cloud NAT            │   │   │
│  │  │  (10.8.1.0/28)    │  │  (outbound internet)  │   │   │
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

## Repository Structure

```
gcp-postgres-terraform/
├── terraform/
│   ├── versions.tf          # Terraform provider requirements
│   ├── variables.tf        # All configurable variables
│   ├── postgres_module.tf   # Core PostgreSQL provisioning
│   ├── outputs.tf          # Connection info, IPs, etc.
│   ├── terraform.tfvars.example
│   └── scripts/
│       ├── postgres_init.sh  # VM startup script
│       └── backup.sh         # Backup cron script
├── schema/
│   └── init.sql             # Base schema (pgvector + minimal)
├── cli/                     # Phase 2: CLI tools
├── api/                     # Phase 3: REST API
├── mcp/                     # Phase 4: MCP server
└── tests/                   # Phase 6: Tests
```

---

## Usage Examples

### Terraform (current)

```hcl
module "postgres" {
  source = "github.com/patelmm79/gcp-postgres-terraform//terraform"

  project_id         = "my-project"
  instance_name      = "my-db"
  postgres_db_name   = "mydb"
  postgres_db_user   = "mydb"
  postgres_db_password = var.my_db_password

  postgres_version = "15"
  machine_type     = "e2-micro"
  disk_size_gb     = 30

  pgvector_enabled = true
  init_sql          = file("schema.sql")
}
```

### CLI (Phase 2)

```bash
gcp-postgres create --name mydb --project my-project --region us-central1
gcp-postgres connect --name mydb
gcp-postgres backup --name mydb
gcp-postgres destroy --name mydb
```

### REST API (Phase 3)

```bash
curl -X POST https://api.example.com/v1/instances \
  -H "Content-Type: application/json" \
  -d '{"name": "mydb", "project": "my-project", "pgvector": true}'
```

### MCP Tools (Phase 4) - for AI agents

```
create_postgres_instance({name: "mydb", project: "my-project", pgvector: true})
destroy_postgres_instance({name: "mydb"})
get_instance_status({name: "mydb"})
trigger_backup({name: "mydb"})
```

---

## Connection Info (after terraform apply)

```bash
# Internal (from within VPC or Cloud Run)
psql -h <internal_ip> -U <user> -d <database>

# External (if assign_external_ip=true)
psql -h <external_ip> -U <user> -d <database>

# Get values from terraform output
terraform output internal_ip
terraform output connection_string_internal
terraform output psql_command_internal
```

---

## Cost (Free Tier Eligible)

| Resource | Configuration | Monthly Est. |
|----------|---------------|--------------|
| Compute Engine | e2-micro (us-central1) | ~$7/mo |
| Persistent Disk | 30GB pd-standard | ~$2/mo |
| Cloud NAT | ~1GB egress | ~$1/mo |
| Secret Manager | 5 secrets | ~$0.15/mo |
| Cloud Storage | 30GB backups | ~$1.50/mo |
| **Total** | | **~$12/mo** |

---

## Roadmap

| Phase | Status | Description |
|-------|--------|-------------|
| Phase 1 | **In Progress** | Extract & parameterize Terraform |
| Phase 2 | Not Started | CLI (`create`, `destroy`, `status`, `connect`, `backup`) |
| Phase 3 | Not Started | REST API (FastAPI) |
| Phase 4 | Not Started | MCP Server (AI agent tools) |
| Phase 5 | Not Started | Schema injection |
| Phase 6 | Not Started | Testing |

See [docs/superpowers/plans/2026-03-31-gcp-postgres-terraform-extraction-plan.md](docs/superpowers/plans/2026-03-31-gcp-postgres-terraform-extraction-plan.md) for full plan.

---

## Contributing

This is part of [dev-nexus](https://github.com/patelmm79/dev-nexus). Issues and PRs welcome.

---

## License

MIT
