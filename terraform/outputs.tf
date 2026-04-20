# =============================================================================
# GCP PostgreSQL Outputs
# =============================================================================

output "instance_name" {
  description = "Name of the PostgreSQL instance"
  value       = google_compute_instance.postgres.name
}

output "subnet_id" {
  description = "ID of the subnet (for Cloud Run connector)"
  value       = local.subnet_id
}

output "project_id" {
  description = "Google Cloud Project ID"
  value       = var.project_id
}

output "region" {
  description = "Region where PostgreSQL is deployed"
  value       = var.region
}

output "zone" {
  description = "Zone where PostgreSQL VM is running"
  value       = google_compute_instance.postgres.zone
}

# =============================================================================
# Network Information
# =============================================================================

output "vpc_network_name" {
  description = "Name of the VPC network"
  value       = local.vpc_name
}

output "vpc_subnet_name" {
  description = "Name of the VPC subnet"
  value       = var.subnet_name != "" ? var.subnet_name : "pg-${var.instance_name}-subnet"
}

output "vpc_connector_name" {
  description = "Name of the VPC connector (for Cloud Run access)"
  value       = var.vpc_name != "" ? null : google_vpc_access_connector.postgres_connector[0].name
}

output "vpc_connector_cidr" {
  description = "CIDR range of the VPC connector (null when using existing VPC)"
  value       = var.vpc_name != "" ? null : (var.vpc_connector_cidr != "" ? var.vpc_connector_cidr : "10.8.1.0/28")
}

# =============================================================================
# IP Addresses
# =============================================================================

output "internal_ip" {
  description = "Internal IP address of PostgreSQL VM"
  value       = google_compute_address.postgres_ip.address
}

output "external_ip" {
  description = "External IP address of PostgreSQL VM (null if no external IP assigned)"
  value       = try(google_compute_instance.postgres.network_interface[0].access_config[0].nat_ip, null)
}

# =============================================================================
# Connection Information
# =============================================================================

output "connection_info" {
  description = "PostgreSQL connection information"
  value = {
    host     = google_compute_address.postgres_ip.address
    port     = 5432
    database = var.postgres_db_name
    user     = var.postgres_db_user
    # Note: password is stored in Secret Manager, not exposed here
  }
}

output "connection_string_internal" {
  description = "PostgreSQL connection string for internal VPC access (password redacted)"
  value       = "postgresql://${var.postgres_db_user}@${google_compute_address.postgres_ip.address}:5432/${var.postgres_db_name}"
}

output "connection_string_external" {
  description = "PostgreSQL connection string for external access (password redacted, only populated if external IP assigned)"
  value       = try(google_compute_instance.postgres.network_interface[0].access_config[0].nat_ip, null) != null ? "postgresql://${var.postgres_db_user}@${google_compute_instance.postgres.network_interface[0].access_config[0].nat_ip}:5432/${var.postgres_db_name}" : null
}

output "psql_command_internal" {
  description = "Command to connect via psql from within VPC"
  value       = "psql -h ${google_compute_address.postgres_ip.address} -U ${var.postgres_db_user} -d ${var.postgres_db_name}"
}

output "psql_command_external" {
  description = "Command to connect via psql from external location (only works if external IP assigned)"
  value       = try(google_compute_instance.postgres.network_interface[0].access_config[0].nat_ip, null) != null ? "psql -h ${google_compute_instance.postgres.network_interface[0].access_config[0].nat_ip} -U ${var.postgres_db_user} -d ${var.postgres_db_name}" : "External IP not assigned. Set assign_external_ip=true to enable."
}

# =============================================================================
# SSH Access
# =============================================================================

output "ssh_command" {
  description = "Command to SSH into the PostgreSQL VM"
  value       = "gcloud compute ssh ${google_compute_instance.postgres.name} --zone=${google_compute_instance.postgres.zone} --project=${var.project_id}"
}

output "ssh_user" {
  description = "Default SSH username"
  value       = "ubuntu"
}

# =============================================================================
# Backup Information
# =============================================================================

output "backup_bucket_name" {
  description = "Name of the GCS bucket used for backups"
  value       = google_storage_bucket.postgres_backups.name
}

output "backup_bucket_url" {
  description = "GCS URL of the backup bucket"
  value       = "gs://${google_storage_bucket.postgres_backups.name}"
}

output "backup_retention_days" {
  description = "Number of days backups are retained"
  value       = var.backup_retention_days
}

# =============================================================================
# PostgreSQL Version and Extensions
# =============================================================================

output "postgres_version" {
  description = "PostgreSQL version installed"
  value       = var.postgres_version
}

output "pgvector_enabled" {
  description = "Whether pgvector extension is enabled"
  value       = var.pgvector_enabled
}

# Note: pgvector_version can be verified on the VM with:
# gcloud compute ssh <instance> --zone=<zone> --project=<project> --command="sudo -u postgres psql -c \"SELECT extversion FROM pg_extension WHERE extname = 'vector';\""
output "pgvector_version" {
  description = "pgvector extension version (verify manually after deployment)"
  value       = var.pgvector_enabled ? "to be verified on VM" : null
  # TODO: Add null_resource with remote-exec to verify actual version after VM creation
}

# =============================================================================
# Resource IDs
# =============================================================================

output "instance_id" {
  description = "Unique ID of the Compute Engine instance"
  value       = google_compute_instance.postgres.id
}

output "disk_id" {
  description = "ID of the persistent data disk"
  value       = google_compute_disk.postgres_data.id
}

output "service_account_email" {
  description = "Email of the PostgreSQL VM service account"
  value       = google_service_account.postgres_vm.email
}

# =============================================================================
# Secrets (Manager (Manager (Manager
# =============================================================================

output "secrets" {
  description = "Secret Manager secret IDs for credentials"
  value = {
    password = google_secret_manager_secret.postgres_password.id
    username = google_secret_manager_secret.postgres_user.id
    database = google_secret_manager_secret.postgres_db.id
    host     = google_secret_manager_secret.postgres_host.id
  }
}

output "secret_names" {
  description = "Secret Manager secret names (for syncing with application secrets)"
  value = {
    password = google_secret_manager_secret.postgres_password.secret_id
    username = google_secret_manager_secret.postgres_user.secret_id
    database = google_secret_manager_secret.postgres_db.secret_id
    host     = google_secret_manager_secret.postgres_host.secret_id
  }
  sensitive = false
}

output "current_secrets" {
  description = "Current secret values (for verification - do not use in production)"
  value = {
    db_name = var.postgres_db_name
    db_user = var.postgres_db_user
    db_host = google_compute_address.postgres_ip.address
  }
  sensitive = false
}

# =============================================================================
# Configuration
# =============================================================================

output "machine_type" {
  description = "VM machine type"
  value       = var.machine_type
}

output "disk_size_gb" {
  description = "Persistent disk size in GB"
  value       = var.disk_size_gb
}

output "disk_type" {
  description = "Persistent disk type"
  value       = var.disk_type
}

# =============================================================================
# Snapshot Policy
# =============================================================================

output "snapshot_policy_name" {
  description = "Name of the disk snapshot policy"
  value       = google_compute_resource_policy.postgres_snapshot_policy.name
}

# =============================================================================
# Metadata (Useful for Debugging)
# =============================================================================

output "instance_metadata" {
  description = "Useful Terraform commands for this instance"
  value = {
    refresh_credentials = "gcloud auth application-default login"
    ssh_command         = "gcloud compute ssh ${google_compute_instance.postgres.name} --zone=${google_compute_instance.postgres.zone} --project=${var.project_id}"
    view_logs           = "gcloud logging read 'resource.type=gce_instance AND resource.labels.instance_name=${google_compute_instance.postgres.name}' --project=${var.project_id}"
    instance_url        = "https://console.cloud.google.com/compute/instancesDetail/zones/${google_compute_instance.postgres.zone}/instances/${google_compute_instance.postgres.name}?project=${var.project_id}"
  }
}
