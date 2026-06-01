variable "project_id" {
  description = "Google Cloud Project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "us-central1-b"
}

variable "repo_prefix" {
  description = "Project prefix for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "postgres_instance_name" {
  description = "Name for the PostgreSQL instance"
  type        = string
}

variable "postgres_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "15"
}

variable "postgres_db_name" {
  description = "Database name"
  type        = string
  default     = "postgres"
}

variable "postgres_db_user" {
  description = "Database user"
  type        = string
  default     = "postgres"
}

variable "postgres_db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "postgres_machine_type" {
  description = "VM machine type"
  type        = string
  default     = "e2-medium"
}

variable "pgvector_enabled" {
  description = "Enable pgvector extension"
  type        = bool
  default     = true
}

variable "github_repo" {
  description = "GitHub repo in owner/name format"
  type        = string
}

variable "subnet_cidr" {
  description = "Subnet CIDR block"
  type        = string
  default     = "10.8.0.0/24"
}

variable "connector_cidr" {
  description = "VPC connector CIDR block"
  type        = string
  default     = "10.8.1.0/28"
}

variable "disk_size_gb" {
  description = "Data disk size in GB"
  type        = number
  default     = 20
}

variable "backup_enabled" {
  description = "Enable GCS backups"
  type        = bool
  default     = true
}

variable "app_image" {
  description = "Container image for Cloud Run app"
  type        = string
  default     = "gcr.io/cloudrun/hello"
}
