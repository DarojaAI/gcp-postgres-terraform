# =============================================================================
# prod.tfvars — Production environment variables for Terraform
# =============================================================================
# Override with actual values before running terraform apply.
#
# Usage:
#   terraform plan -var-file="prod.tfvars"
#   terraform apply -var-file="prod.tfvars"
#
# Sensitive values should come from GitHub Actions secrets (TF_VAR_xxx),
# not hardcoded here.
# =============================================================================

project_id              = "YOUR_GCP_PROJECT_ID"
instance_name           = "rag-pg"
region                  = "us-central1"
zone                    = "us-central1-b"
postgres_version        = "15"
pgvector_enabled        = true

# Machine type — e2-small for pgvector (e2-micro is too small)
machine_type            = "e2-small"

# PostgreSQL configuration
postgres_db_name         = "rag_taxonomy"
postgres_db_user         = "rag_admin"
postgres_db_password     = "CHANGEME"  # Override via TF_VAR_postgres_db_password env var
max_connections         = "50"
shared_buffers           = "256MB"
work_mem                 = "8MB"
maintenance_work_mem     = "64MB"

# Network
vpc_name                = "rag-verifier-vpc"
subnet_cidr             = "10.10.1.0/28"
vpc_connector_cidr      = "10.10.2.0/28"
enable_cloud_nat        = true

# Firewall
allow_postgres_from_cidrs = ["10.0.0.0/8"]
allow_ssh_from_cidrs     = []

# Storage
disk_type               = "pd-standard"
disk_size_gb            = 50
backup_retention_days   = 7
snapshot_retention_days = 7

# Backup
backup_bucket_name       = "rag-postgres-backups"

# Init SQL — load the taxonomy schema
# This is passed directly; for file reference use:
# init_sql = file("../schema/extensions/rag_taxonomy.sql")
init_sql = <<-EOT
-- rag_taxonomy schema loaded via GitHub Actions terraform-apply workflow
-- See: schema/extensions/rag_taxonomy.sql
CREATE EXTENSION IF NOT EXISTS vector;
EOT

# Monitoring
enable_monitoring       = true
disk_usage_alert_threshold = 85
alert_notification_channels = []

# High availability
preemptible            = false
assign_external_ip     = false

# Labels
labels = {
  project     = "rag-research-tool"
  environment = "prod"
  managed_by  = "terraform"
  repo        = "gcp-postgres-terraform"
}
