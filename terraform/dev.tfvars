# =============================================================================
# dev.tfvars — Development environment
# =============================================================================
# Same as prod but smaller footprint for testing.

project_id       = "YOUR_GCP_PROJECT_ID"
instance_name    = "rag-pg-dev"
region           = "us-central1"
zone             = "us-central1-b"
postgres_version = "15"
pgvector_enabled = true
machine_type     = "e2-small"

postgres_db_name     = "rag_taxonomy_dev"
postgres_db_user     = "rag_dev"
postgres_db_password = "CHANGEME"
max_connections      = "20"
shared_buffers       = "128MB"
work_mem             = "4MB"
maintenance_work_mem = "32MB"

vpc_name           = "rag-verifier-vpc-dev"
subnet_cidr        = "10.11.1.0/28"
vpc_connector_cidr = "10.11.2.0/28"
enable_cloud_nat   = true

allow_postgres_from_cidrs = ["10.0.0.0/8"]
allow_ssh_from_cidrs      = []

disk_type               = "pd-standard"
disk_size_gb            = 20
backup_retention_days   = 3
snapshot_retention_days = 3

backup_bucket_name = "rag-postgres-backups-dev"

init_sql = <<-EOT
CREATE EXTENSION IF NOT EXISTS vector;
EOT

github_actions_enabled = true
github_repo            = "patelmm79/gcp-postgres-terraform"
github_owner           = "patelmm79"

enable_monitoring           = false
disk_usage_alert_threshold  = 90
alert_notification_channels = []

preemptible        = false
assign_external_ip = false

labels = {
  project     = "rag-research-tool"
  environment = "dev"
  managed_by  = "terraform"
  repo        = "gcp-postgres-terraform"
}
