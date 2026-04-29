# =============================================================================
# GCP PostgreSQL Terraform Module - Root Wrapper
#
# This module follows Terraform standard structure by providing the primary
# entrypoint at the repository root. It wraps and re-exports the nested
# module in the ./terraform directory.
#
# See: https://developer.hashicorp.com/terraform/language/modules/develop/structure
# =============================================================================

module "postgres_module" {
  source = "./terraform"

  # Required variables
  project_id    = var.project_id
  instance_name = var.instance_name
  region        = var.region
  zone          = var.zone
  environment   = var.environment
  repo_prefix   = var.repo_prefix

  # VPC configuration
  vpc_name    = var.vpc_name
  subnet_name = var.subnet_name

  # PostgreSQL configuration
  postgres_version     = var.postgres_version
  postgres_db_name     = var.postgres_db_name
  postgres_db_user     = var.postgres_db_user
  postgres_db_password = var.postgres_db_password

  # Machine configuration
  machine_type = var.machine_type
  disk_size_gb = var.disk_size_gb
  disk_type    = var.disk_type

  # Networking
  assign_external_ip         = var.assign_external_ip
  allow_postgres_from_cidrs  = var.allow_postgres_from_cidrs
  allow_ssh_from_cidrs       = var.allow_ssh_from_cidrs
  vpc_connector_min_instances = var.vpc_connector_min_instances
  vpc_connector_max_instances = var.vpc_connector_max_instances

  # Backup configuration
  enable_backups           = var.enable_backups
  backup_bucket_name       = var.backup_bucket_name
  backup_retention_days    = var.backup_retention_days
  backup_schedule          = var.backup_schedule
  snapshot_retention_days  = var.snapshot_retention_days

  # Monitoring
  enable_monitoring            = var.enable_monitoring
  disk_usage_alert_threshold   = var.disk_usage_alert_threshold
  alert_notification_channels  = var.alert_notification_channels

  # PostgreSQL runtime configuration
  max_connections       = var.max_connections
  shared_buffers        = var.shared_buffers
  work_mem              = var.work_mem
  maintenance_work_mem  = var.maintenance_work_mem

  # Schema injection
  init_sql         = var.init_sql
  pgvector_enabled = var.pgvector_enabled

  # Advanced
  enable_cloud_nat                      = var.enable_cloud_nat
  preemptible                           = var.preemptible
  github_actions_backup_reader_sa       = var.github_actions_backup_reader_sa
  enable_oslogin                        = var.enable_oslogin
  vpc_connector_cidr                    = var.vpc_connector_cidr

  # Labels
  labels = var.labels
}

# =============================================================================
# Re-export all outputs from nested module
# =============================================================================

output "instance_name" {
  description = "PostgreSQL instance name"
  value       = module.postgres_module.instance_name
}

output "instance_id" {
  description = "PostgreSQL instance ID"
  value       = module.postgres_module.instance_id
}

output "postgres_internal_ip" {
  description = "PostgreSQL internal IP address"
  value       = module.postgres_module.postgres_internal_ip
}

output "postgres_external_ip" {
  description = "PostgreSQL external IP address (if assigned)"
  value       = module.postgres_module.postgres_external_ip
}

output "postgres_password_secret" {
  description = "Secret Manager secret reference for PostgreSQL password"
  value       = module.postgres_module.postgres_password_secret
}

output "postgres_user_secret" {
  description = "Secret Manager secret reference for PostgreSQL user"
  value       = module.postgres_module.postgres_user_secret
}

output "postgres_db_secret" {
  description = "Secret Manager secret reference for PostgreSQL database"
  value       = module.postgres_module.postgres_db_secret
}

output "postgres_host_secret" {
  description = "Secret Manager secret reference for PostgreSQL host"
  value       = module.postgres_module.postgres_host_secret
}

output "backup_bucket_name" {
  description = "GCS bucket name for backups"
  value       = module.postgres_module.backup_bucket_name
}

output "vpc_connector_name" {
  description = "VPC Access Connector name"
  value       = module.postgres_module.vpc_connector_name
}

output "postgres_service_account" {
  description = "PostgreSQL VM service account email"
  value       = module.postgres_module.postgres_service_account
}
