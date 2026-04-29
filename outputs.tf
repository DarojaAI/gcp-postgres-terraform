# =============================================================================
# GCP PostgreSQL Module - Root Outputs
# 
# Re-exports outputs from the nested postgres_module
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
  description = "PostgreSQL external IP address (if assigned)"
  value       = module.postgres_module.external_ip
}

output "postgres_external_ip" {
  description = "PostgreSQL external IP address (alias)"
  value       = module.postgres_module.external_ip
}

output "postgres_password_secret" {
  description = "Secret Manager secret reference for PostgreSQL password"
  value       = try(module.postgres_module.secrets["password"], "")
}

output "postgres_user_secret" {
  description = "Secret Manager secret reference for PostgreSQL user"
  value       = try(module.postgres_module.secrets["user"], "")
}

output "postgres_db_secret" {
  description = "Secret Manager secret reference for PostgreSQL database"
  value       = try(module.postgres_module.secrets["db"], "")
}

output "postgres_host_secret" {
  description = "Secret Manager secret reference for PostgreSQL host"
  value       = try(module.postgres_module.secrets["host"], "")
}

output "backup_bucket_name" {
  description = "GCS bucket name for backups"
  value       = module.postgres_module.backup_bucket_name
}

output "backup_bucket_url" {
  description = "GCS bucket URL for backups"
  value       = module.postgres_module.backup_bucket_url
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

output "service_account_email" {
  description = "PostgreSQL VM service account email"
  value       = module.postgres_module.service_account_email
}

output "vpc_network_name" {
  description = "VPC network name"
  value       = module.postgres_module.vpc_network_name
}

output "vpc_subnet_name" {
  description = "VPC subnet name"
  value       = module.postgres_module.vpc_subnet_name
}

output "machine_type" {
  description = "Machine type for PostgreSQL VM"
  value       = module.postgres_module.machine_type
}

output "disk_size_gb" {
  description = "PostgreSQL data disk size"
  value       = module.postgres_module.disk_size_gb
}

output "disk_type" {
  description = "PostgreSQL disk type"
  value       = module.postgres_module.disk_type
}

output "postgres_version" {
  description = "PostgreSQL version"
  value       = module.postgres_module.postgres_version
}

output "pgvector_enabled" {
  description = "Whether pgvector extension is enabled"
  value       = module.postgres_module.pgvector_enabled
}

output "instance_metadata" {
  description = "Complete instance metadata"
  value       = module.postgres_module.instance_metadata
}
