# =============================================================================
# GCP PostgreSQL Terraform Module - Root Variables
#
# This file re-declares all variables from the nested module so that Terraform
# treats them as root module inputs, enabling proper git module source loading.
#
# See: https://developer.hashicorp.com/terraform/language/modules/develop/structure
# =============================================================================

variable "project_id" {
  description = "Google Cloud Project ID"
  type        = string
}

variable "repo_prefix" {
  description = "Repository/project prefix for resource naming (e.g., rag-research)"
  type        = string
  default     = "rag-research"
}

variable "environment" {
  description = "Environment name for resource naming (e.g., eai, prod)"
  type        = string
  default     = "prod"
}

variable "instance_name" {
  description = "Name for this PostgreSQL instance"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{2,}[a-z0-9]$", var.instance_name))
    error_message = "Instance name must start and end with lowercase letter or number, contain only lowercase letters, numbers, and hyphens, and be at least 4 characters."
  }
}

variable "region" {
  description = "Google Cloud region for deployment"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Google Cloud zone (must be within region, e.g. us-central1-b)"
  type        = string
  default     = "us-central1-b"
}

variable "postgres_version" {
  description = "PostgreSQL major version"
  type        = string
  default     = "15"

  validation {
    condition     = contains(["14", "15", "16"], var.postgres_version)
    error_message = "PostgreSQL version must be 14, 15, or 16."
  }
}

variable "postgres_db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "postgres"
}

variable "postgres_db_user" {
  description = "PostgreSQL database user"
  type        = string
  default     = "postgres"
}

variable "postgres_db_password" {
  description = "PostgreSQL database password"
  type        = string
  sensitive   = true
}

variable "machine_type" {
  description = "Machine type for PostgreSQL VM"
  type        = string
  default     = "e2-micro"

  validation {
    condition     = contains(["e2-micro", "e2-small", "e2-medium", "n1-standard-1", "n1-standard-2"], var.machine_type)
    error_message = "Machine type must be e2-micro, e2-small, e2-medium, n1-standard-1, or n1-standard-2."
  }
}

variable "disk_size_gb" {
  description = "Persistent disk size for PostgreSQL data in GB"
  type        = number
  default     = 30

  validation {
    condition     = var.disk_size_gb >= 10 && var.disk_size_gb <= 1000
    error_message = "Disk size must be between 10 and 1000 GB."
  }
}

variable "disk_type" {
  description = "Type of persistent disk"
  type        = string
  default     = "pd-standard"

  validation {
    condition     = contains(["pd-standard", "pd-ssd", "pd-balanced"], var.disk_type)
    error_message = "Disk type must be pd-standard, pd-ssd, or pd-balanced."
  }
}

variable "vpc_name" {
  description = "Name of existing VPC network"
  type        = string

  validation {
    condition     = var.vpc_name != ""
    error_message = "vpc_name is required and cannot be empty."
  }
}

variable "subnet_name" {
  description = "Name of existing subnet"
  type        = string

  validation {
    condition     = var.subnet_name != ""
    error_message = "subnet_name is required and cannot be empty."
  }
}

variable "vpc_connector_cidr" {
  description = "DEPRECATED: VPC connector is now created by vpc-infra module. This variable is ignored."
  type        = string
  default     = "10.10.2.0/28"
}

variable "allow_postgres_from_cidrs" {
  description = "List of CIDR ranges allowed to connect to PostgreSQL"
  type        = list(string)
  default     = []
}

variable "allow_ssh_from_cidrs" {
  description = "List of CIDR ranges allowed to SSH to PostgreSQL VM"
  type        = list(string)
  default     = []
}

variable "assign_external_ip" {
  description = "Assign an external (public) IP to the PostgreSQL VM"
  type        = bool
  default     = false
}

variable "vpc_connector_min_instances" {
  description = "Minimum instances for VPC connector"
  type        = number
  default     = 2
}

variable "vpc_connector_max_instances" {
  description = "Maximum instances for VPC connector"
  type        = number
  default     = 3
}

variable "enable_backups" {
  description = "Enable daily automatic PostgreSQL backups to GCS"
  type        = bool
  default     = true
}

variable "backup_bucket_name" {
  description = "Name of GCS bucket for backups (auto-generated if empty)"
  type        = string
  default     = ""
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 30

  validation {
    condition     = var.backup_retention_days >= 7 && var.backup_retention_days <= 365
    error_message = "Backup retention must be between 7 and 365 days."
  }
}

variable "backup_schedule" {
  description = "Cron schedule for automated backups (default: 2am UTC daily)"
  type        = string
  default     = "0 2 * * *"
}

variable "snapshot_retention_days" {
  description = "Number of days to retain disk snapshots"
  type        = number
  default     = 30

  validation {
    condition     = var.snapshot_retention_days >= 7 && var.snapshot_retention_days <= 365
    error_message = "Snapshot retention must be between 7 and 365 days."
  }
}

variable "enable_monitoring" {
  description = "Enable Cloud Monitoring dashboards and alerts for PostgreSQL"
  type        = bool
  default     = true
}

variable "disk_usage_alert_threshold" {
  description = "Disk usage percentage threshold for alerts"
  type        = number
  default     = 80

  validation {
    condition     = var.disk_usage_alert_threshold > 0 && var.disk_usage_alert_threshold <= 100
    error_message = "Alert threshold must be between 1 and 100."
  }
}

variable "alert_notification_channels" {
  description = "List of notification channel IDs for alerts"
  type        = list(string)
  default     = []
}

variable "max_connections" {
  description = "Maximum number of concurrent PostgreSQL connections"
  type        = number
  default     = 100
}

variable "shared_buffers" {
  description = "PostgreSQL shared_buffers setting"
  type        = string
  default     = "256MB"
}

variable "work_mem" {
  description = "PostgreSQL work_mem setting"
  type        = string
  default     = "4MB"
}

variable "maintenance_work_mem" {
  description = "PostgreSQL maintenance_work_mem setting"
  type        = string
  default     = "64MB"
}

variable "init_sql" {
  description = "SQL to run after PostgreSQL and pgvector are installed"
  type        = string
  default     = ""
}

variable "pgvector_enabled" {
  description = "Enable pgvector extension for vector similarity search"
  type        = bool
  default     = true
}

variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "enable_cloud_nat" {
  description = "Enable Cloud NAT for outbound internet access"
  type        = bool
  default     = true
}

variable "preemptible" {
  description = "Use preemptible VM (lower cost but may be terminated by GCP)"
  type        = bool
  default     = false
}

variable "github_actions_backup_reader_sa" {
  description = "GitHub Actions deploy SA email that needs read access to the backup bucket"
  type        = string
  default     = ""
}

variable "enable_oslogin" {
  description = "Enable OS Login for SSH access"
  type        = bool
  default     = true
}
