output "postgres_internal_ip" {
  description = "Internal IP of the PostgreSQL instance"
  value       = module.postgres.internal_ip
}

output "postgres_secret_ids" {
  description = "Secret Manager secret IDs"
  value       = module.postgres.secret_ids
  sensitive   = true
}

output "vpc_connector_id" {
  description = "VPC access connector ID"
  value       = module.postgres.vpc_connector_id
}

output "cloud_run_service_url" {
  description = "URL of the deployed Cloud Run service"
  value       = google_cloud_run_v2_service.app.uri
}

output "cloud_run_service_account" {
  description = "Service account email used by Cloud Run"
  value       = module.postgres.cloud_run_service_account_email
}
