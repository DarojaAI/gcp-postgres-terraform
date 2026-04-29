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

  project_id  = var.project_id
  region      = var.region
  zone        = var.zone
  environment = var.environment
  repo_prefix = var.repo_prefix

  vpc_name    = var.vpc_name
  subnet_name = var.subnet_name

  instance_name = var.instance_name
  machine_type  = var.machine_type

  postgres_version     = var.postgres_version
  postgres_db_name     = var.postgres_db_name
  postgres_db_user     = var.postgres_db_user
  postgres_db_password = var.postgres_db_password

  disk_size_gb = var.disk_size_gb

  assign_external_ip = var.assign_external_ip

  labels = var.labels
}

# =============================================================================
# Re-export key outputs from nested module
# =============================================================================

output "instance_name" {
  description = "PostgreSQL instance name"
  value       = module.postgres_module.instance_name
}

output "instance_id" {
  description = "PostgreSQL instance ID"
  value       = module.postgres_module.instance_id
}

output "internal_ip" {
  description = "PostgreSQL internal IP address"
  value       = module.postgres_module.internal_ip
}

output "postgres_internal_ip" {
  description = "PostgreSQL internal IP address (alias)"
  value       = module.postgres_module.internal_ip
}

output "external_ip" {
  description = "PostgreSQL external IP address"
  value       = module.postgres_module.external_ip
}

output "postgres_external_ip" {
  description = "PostgreSQL external IP address (alias)"
  value       = module.postgres_module.external_ip
}

output "connection_info" {
  description = "Connection information"
  value       = module.postgres_module.connection_info
}

output "connection_string_internal" {
  description = "PostgreSQL connection string (internal VPC)"
  value       = module.postgres_module.connection_string_internal
  sensitive   = true
}

output "connection_string_external" {
  description = "PostgreSQL connection string (external IP if assigned)"
  value       = module.postgres_module.connection_string_external
  sensitive   = true
}

output "psql_command_internal" {
  description = "psql command for internal connection"
  value       = module.postgres_module.psql_command_internal
}

output "psql_command_external" {
  description = "psql command for external connection"
  value       = module.postgres_module.psql_command_external
}

output "ssh_command" {
  description = "SSH command to connect to PostgreSQL VM"
  value       = module.postgres_module.ssh_command
}

output "ssh_user" {
  description = "SSH user for PostgreSQL VM"
  value       = module.postgres_module.ssh_user
}

output "backup_bucket_name" {
  description = "GCS bucket name for backups"
  value       = module.postgres_module.backup_bucket_name
}

output "backup_bucket_url" {
  description = "GCS bucket URL for backups"
  value       = module.postgres_module.backup_bucket_url
}

output "backup_retention_days" {
  description = "Backup retention period"
  value       = module.postgres_module.backup_retention_days
}

output "postgres_version" {
  description = "PostgreSQL version"
  value       = module.postgres_module.postgres_version
}

output "pgvector_enabled" {
  description = "Whether pgvector extension is enabled"
  value       = module.postgres_module.pgvector_enabled
}

output "service_account_email" {
  description = "PostgreSQL VM service account email"
  value       = module.postgres_module.service_account_email
}

output "postgres_service_account" {
  description = "PostgreSQL VM service account email (alias)"
  value       = module.postgres_module.service_account_email
}

output "secrets" {
  description = "Secret Manager secrets map"
  value       = module.postgres_module.current_secrets
  sensitive   = true
}

output "instance_metadata" {
  description = "Complete instance metadata"
  value       = module.postgres_module.instance_metadata
}
