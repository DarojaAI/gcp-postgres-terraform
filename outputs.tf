# =============================================================================
# GCP PostgreSQL Module - Root Outputs
# 
# Re-exports key outputs from the nested postgres_module.
# For complete outputs, see terraform/outputs.tf
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
  description = "PostgreSQL internal IP address (alias for compatibility)"
  value       = module.postgres_module.internal_ip
}

output "external_ip" {
  description = "PostgreSQL external IP address (if assigned)"
  value       = module.postgres_module.external_ip
}

output "postgres_external_ip" {
  description = "PostgreSQL external IP address (alias for compatibility)"
  value       = module.postgres_module.external_ip
}

output "postgres_password_secret" {
  description = "Secret Manager secret reference for PostgreSQL password"
  value       = try(module.postgres_module.secrets["password"], "")
}

output "connection_string_internal" {
  description = "PostgreSQL connection string (internal VPC)"
  value       = module.postgres_module.connection_string_internal
  sensitive   = true
}

output "ssh_command" {
  description = "SSH command to connect to PostgreSQL VM"
  value       = module.postgres_module.ssh_command
}

output "service_account_email" {
  description = "PostgreSQL VM service account email"
  value       = module.postgres_module.service_account_email
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
