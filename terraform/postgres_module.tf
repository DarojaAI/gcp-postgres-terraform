# =============================================================================
# GCP PostgreSQL on Compute Engine - Main Provisioning Module
# =============================================================================
# Creates a PostgreSQL instance on GCP Compute Engine with:
# - VPC network with subnet
# - Persistent data disk
# - PostgreSQL with configurable version and pgvector
# - Cloud NAT for internet access
# - VPC Access connector for Cloud Run
# - Automated backups to GCS
# - Disk snapshots for disaster recovery
# - Monitoring dashboards
# =============================================================================

# Fetch GitHub Actions runner IP ranges for firewall allowlisting
# Enables DBT schema validation in CI/CD workflows to connect to PostgreSQL
data "http" "github_actions_ips" {
  url = "https://api.github.com/meta"
  request_headers = {
    Accept = "application/vnd.github+json"
  }
}

# Extract and filter IPv4-only CIDRs from GitHub Actions IPs
# IPv4 CIDRs look like "13.64.0.0/11" - we aggregate to /16 blocks
# IPv6 addresses (containing ':') are filtered out as GCP firewall doesn't accept them
locals {
  github_actions_ipv4 = [for cidr in jsondecode(data.http.github_actions_ips.response_body).actions :
    length(regexall(":", cidr)) > 0 ? "" : format("%s.0.0/16", join(".", slice(split(".", cidr), 0, 2)))
  ]
  github_actions_cidrs = distinct(local.github_actions_ipv4)
}

# Enable required GCP APIs
resource "google_project_service" "compute" {
  project            = var.project_id
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "servicenetworking" {
  project            = var.project_id
  service            = "servicenetworking.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "vpcaccess" {
  project            = var.project_id
  service            = "vpcaccess.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "secretmanager" {
  project            = var.project_id
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

# =============================================================================
# VPC Network (use existing or create new)
# =============================================================================

# Data source for existing VPC (when vpc_name is provided)
data "google_compute_network" "existing" {
  count  = var.vpc_name != "" ? 1 : 0
  name   = var.vpc_name
  project = var.project_id
}

# Data source for existing subnet (when subnet_name is provided)
data "google_compute_subnetwork" "existing" {
  count   = var.subnet_name != "" ? 1 : 0
  name    = var.subnet_name
  region  = var.region
  project = var.project_id
}

# Create new VPC only if not provided
resource "google_compute_network" "postgres_network" {
  count                 = var.vpc_name != "" ? 0 : 1
  project               = var.project_id
  name                  = "pg-${var.instance_name}-vpc"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.compute]
}

# Create new subnet only if not provided
resource "google_compute_subnetwork" "postgres_subnet" {
  count         = var.subnet_name != "" ? 0 : 1
  project       = var.project_id
  name          = "pg-${var.instance_name}-subnet"
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = var.vpc_name != "" ? data.google_compute_network.existing[0].id : google_compute_network.postgres_network[0].id

  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }

  depends_on = [google_compute_network.postgres_network]
}

# Unified references for network and subnet
locals {
  vpc_id     = var.vpc_name != "" ? data.google_compute_network.existing[0].id : google_compute_network.postgres_network[0].id
  vpc_name   = var.vpc_name != "" ? var.vpc_name : google_compute_network.postgres_network[0].name
  subnet_id  = var.subnet_name != "" ? data.google_compute_subnetwork.existing[0].id : google_compute_subnetwork.postgres_subnet[0].id
  subnet_cidr = var.subnet_name != "" ? data.google_compute_subnetwork.existing[0].ip_cidr_range : var.subnet_cidr
}

# =============================================================================
# Firewall Rules
# =============================================================================

resource "google_compute_firewall" "allow_postgres" {
  project = var.project_id
  name    = "pg-${var.instance_name}-allow-postgres"
  network = local.vpc_name

  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }

  # Allow connections from:
  # 1. PostgreSQL subnet (VPC-internal)
  # 2. VPC connector CIDR (Cloud Run -> PostgreSQL)
  # 3. GitHub Actions runners (for CI/CD DBT validation)
  # 4. Extra external sources (if configured)
  # IPv6 entries are filtered out (empty strings removed by compact)
  source_ranges = compact(distinct(concat(
    [local.subnet_cidr],
    var.vpc_connector_cidr != "" ? [var.vpc_connector_cidr] : [],
    local.github_actions_cidrs,
    var.allow_postgres_from_cidrs
  )))
  target_tags = ["postgres-server"]
}

resource "google_compute_firewall" "allow_ssh" {
  project = var.project_id
  count   = length(var.allow_ssh_from_cidrs) > 0 ? 1 : 0
  name    = "pg-${var.instance_name}-allow-ssh"
  network = local.vpc_name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.allow_ssh_from_cidrs
  target_tags   = ["postgres-server"]
}

resource "google_compute_firewall" "allow_egress" {
  project = var.project_id
  count   = var.enable_cloud_nat ? 1 : 0
  name    = "pg-${var.instance_name}-allow-egress"
  network = local.vpc_name

  direction = "EGRESS"

  allow {
    protocol = "all"
  }

  destination_ranges = ["0.0.0.0/0"]
  target_tags        = ["postgres-server"]
}

# =============================================================================
# Cloud NAT (for outbound internet access)
# =============================================================================

resource "google_compute_router" "postgres_router" {
  project = var.project_id
  count   = var.enable_cloud_nat && var.vpc_name == "" ? 1 : 0
  name    = "pg-${var.instance_name}-router"
  region  = var.region
  network = local.vpc_id

  depends_on = [google_compute_network.postgres_network]
}

resource "google_compute_router_nat" "postgres_nat" {
  project = var.project_id
  count   = var.enable_cloud_nat && var.vpc_name == "" ? 1 : 0
  name    = "pg-${var.instance_name}-nat"
  router  = google_compute_router.postgres_router[0].name
  region  = var.region

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = local.subnet_id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# =============================================================================
# VPC Access Connector (for Cloud Run to PostgreSQL access)
# =============================================================================
# Only create if not using existing VPC (to avoid conflicts)

resource "google_vpc_access_connector" "postgres_connector" {
  count         = var.vpc_name != "" ? 0 : 1
  project       = var.project_id
  name          = "pg-${var.instance_name}-connector"
  region        = var.region
  network       = local.vpc_name
  ip_cidr_range = var.vpc_connector_cidr != "" ? var.vpc_connector_cidr : "10.8.1.0/28"
  min_instances = var.vpc_connector_min_instances
  max_instances = var.vpc_connector_max_instances

  depends_on = [
    google_project_service.vpcaccess,
    google_compute_subnetwork.postgres_subnet,
    data.google_compute_subnetwork.existing
  ]
}

# =============================================================================
# Cloud Storage for Backups
# =============================================================================

resource "google_storage_bucket" "postgres_backups" {
  project       = var.project_id
  name          = var.backup_bucket_name != "" ? var.backup_bucket_name : "${var.repo_prefix}-${var.environment}-postgres-backups"
  location      = var.region
  force_destroy = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = var.backup_retention_days
    }
    action {
      type = "Delete"
    }
  }

  lifecycle_rule {
    condition {
      num_newer_versions = 3
    }
    action {
      type = "Delete"
    }
  }

  uniform_bucket_level_access = true
}

# =============================================================================
# Persistent Data Disk
# =============================================================================

resource "google_compute_disk" "postgres_data" {
  project = var.project_id
  name    = "pg-${var.instance_name}-data"
  type    = var.disk_type
  zone    = var.zone
  size    = var.disk_size_gb
  labels = merge(var.labels, {
    instance = var.instance_name
    type     = "database"
    disk     = "data"
  })
}

# =============================================================================
# Static IP Addresses
# =============================================================================

resource "google_compute_address" "postgres_ip" {
  project      = var.project_id
  name         = "pg-${var.instance_name}-ip"
  address_type = "INTERNAL"
  subnetwork   = local.subnet_id
  region       = var.region
}

resource "google_compute_address" "postgres_external_ip" {
  project      = var.project_id
  count        = var.assign_external_ip ? 1 : 0
  name         = "pg-${var.instance_name}-external-ip"
  address_type = "EXTERNAL"
  network_tier = "STANDARD"
  region       = var.region
}

# =============================================================================
# Service Account for PostgreSQL VM
# =============================================================================

resource "google_service_account" "postgres_vm" {
  project      = var.project_id
  account_id   = "pg-${var.instance_name}-vm"
  display_name = "PostgreSQL VM - ${var.instance_name}"
  description  = "Service account for PostgreSQL VM ${var.instance_name}"
}

resource "google_storage_bucket_iam_member" "postgres_backup_writer" {
  bucket = google_storage_bucket.postgres_backups.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.postgres_vm.email}"
}

resource "google_storage_bucket_iam_member" "postgres_backup_reader" {
  bucket = google_storage_bucket.postgres_backups.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.postgres_vm.email}"
}

# Grant GitHub Actions deploy SA read access to backups (for terraform plan refresh).
# Controlled by var.github_actions_backup_reader_sa — set to the SA email used by GitHub Actions WIF.
resource "google_storage_bucket_iam_member" "github_actions_backup_reader" {
  count  = var.github_actions_backup_reader_sa != "" ? 1 : 0
  bucket = google_storage_bucket.postgres_backups.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${var.github_actions_backup_reader_sa}"
}

# =============================================================================
# Secret Manager Secrets for Credentials
# =============================================================================

resource "google_secret_manager_secret" "postgres_password" {
  project   = var.project_id
  secret_id = "${var.repo_prefix}-${var.environment}-postgres-password"
  replication {
    auto {}
  }
  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "postgres_password" {
  secret      = google_secret_manager_secret.postgres_password.id
  secret_data = var.postgres_db_password
}

resource "google_secret_manager_secret" "postgres_user" {
  project   = var.project_id
  secret_id = "${var.repo_prefix}-${var.environment}-postgres-user"
  replication {
    auto {}
  }
  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "postgres_user" {
  secret      = google_secret_manager_secret.postgres_user.id
  secret_data = var.postgres_db_user
}

resource "google_secret_manager_secret" "postgres_db" {
  project   = var.project_id
  secret_id = "${var.repo_prefix}-${var.environment}-postgres-db"
  replication {
    auto {}
  }
  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "postgres_db" {
  secret      = google_secret_manager_secret.postgres_db.id
  secret_data = var.postgres_db_name
}

resource "google_secret_manager_secret" "postgres_host" {
  project   = var.project_id
  secret_id = "${var.repo_prefix}-${var.environment}-postgres-host"
  replication {
    auto {}
  }
  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "postgres_host" {
  secret      = google_secret_manager_secret.postgres_host.id
  secret_data = google_compute_address.postgres_ip.address
}

resource "google_secret_manager_secret_iam_member" "postgres_vm_secret_access" {
  secret_id = google_secret_manager_secret.postgres_password.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.postgres_vm.email}"
}

# =============================================================================
# PostgreSQL VM Instance
# =============================================================================

resource "google_compute_instance" "postgres" {
  project      = var.project_id
  name         = "pg-${var.instance_name}"
  machine_type = var.machine_type
  zone         = var.zone

  can_ip_forward = true

  tags = ["postgres-server"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = "20"
      type  = "pd-standard"
    }
  }

  attached_disk {
    source      = google_compute_disk.postgres_data.id
    device_name = "postgres-data"
  }

  network_interface {
    subnetwork = local.subnet_id
    network_ip = google_compute_address.postgres_ip.address

    dynamic "access_config" {
      for_each = var.assign_external_ip ? [1] : []
      content {
        nat_ip       = google_compute_address.postgres_external_ip[0].address
        network_tier = "STANDARD"
      }
    }
  }

  metadata = {
    enable-oslogin = var.enable_oslogin ? "TRUE" : "FALSE"
  }

  metadata_startup_script = templatefile("${path.module}/scripts/postgres_init.sh", {
    db_name              = var.postgres_db_name
    db_user              = var.postgres_db_user
    db_password          = var.postgres_db_password
    postgres_version     = var.postgres_version
    backup_bucket        = google_storage_bucket.postgres_backups.name
    data_disk_device     = "sdb"
    pgvector_enabled     = var.pgvector_enabled
    init_sql             = var.init_sql
    max_connections      = var.max_connections
    shared_buffers       = var.shared_buffers
    work_mem             = var.work_mem
    maintenance_work_mem = var.maintenance_work_mem
    retry_delay          = "2"
    internal_ip          = google_compute_address.postgres_ip.address
    INTERNAL_IP          = google_compute_address.postgres_ip.address
  })

  service_account {
    email  = google_service_account.postgres_vm.email
    scopes = ["cloud-platform"]
  }

  scheduling {
    automatic_restart   = !var.preemptible
    on_host_maintenance = var.preemptible ? "TERMINATE" : "MIGRATE"
    preemptible         = var.preemptible
  }

  allow_stopping_for_update = true

  labels = merge(var.labels, {
    instance = var.instance_name
    type     = "database"
    role     = "postgresql"
  })

  depends_on = [
    google_project_service.compute,
    local.subnet_id,
    google_storage_bucket.postgres_backups,
    google_compute_disk.postgres_data,
    google_vpc_access_connector.postgres_connector[0]
  ]
}

# =============================================================================
# Automated Disk Snapshots
# =============================================================================

resource "google_compute_resource_policy" "postgres_snapshot_policy" {
  project     = var.project_id
  region      = var.region
  name        = "pg-${var.instance_name}-snapshots"
  description = "Daily snapshots of PostgreSQL data disk"

  snapshot_schedule_policy {
    schedule {
      daily_schedule {
        days_in_cycle = 1
        start_time    = "02:00"
      }
    }

    retention_policy {
      max_retention_days = var.snapshot_retention_days
    }

    snapshot_properties {
      storage_locations = [var.region]
    }
  }
}

resource "google_compute_disk_resource_policy_attachment" "postgres_snapshots" {
  project = var.project_id
  name    = google_compute_resource_policy.postgres_snapshot_policy.name
  disk    = google_compute_disk.postgres_data.name
  zone    = var.zone
}

# =============================================================================
# Monitoring (Optional)
# =============================================================================

resource "google_monitoring_dashboard" "postgres" {
  project = var.project_id
  count   = var.enable_monitoring ? 1 : 0

  dashboard_json = jsonencode({
    displayName = "PostgreSQL Dashboard - ${var.instance_name}"
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          xPos   = 0
          yPos   = 0
          width  = 6
          height = 4
          widget = {
            title = "CPU Utilization"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"compute.googleapis.com/instance/cpu/utilization\" AND resource.type=\"gce_instance\" AND resource.labels.instance_id=\"${google_compute_instance.postgres.instance_id}\""
                    aggregation = {
                      alignmentPeriod  = "60s"
                      perSeriesAligner = "ALIGN_MEAN"
                    }
                  }
                }
              }]
            }
          }
        },
        {
          xPos   = 6
          yPos   = 0
          width  = 6
          height = 4
          widget = {
            title = "Disk Usage"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"agent.googleapis.com/disk/percent_used\" AND resource.type=\"gce_instance\" AND resource.labels.instance_id=\"${google_compute_instance.postgres.instance_id}\""
                    aggregation = {
                      alignmentPeriod  = "60s"
                      perSeriesAligner = "ALIGN_MEAN"
                    }
                  }
                }
              }]
            }
          }
        }
      ]
    }
  })
}

resource "google_monitoring_alert_policy" "postgres_disk_usage" {
  project      = var.project_id
  count        = var.enable_monitoring && length(var.alert_notification_channels) > 0 ? 1 : 0
  display_name = "PostgreSQL Disk Usage High - ${var.instance_name}"
  combiner     = "OR"

  conditions {
    display_name = "Disk usage > ${var.disk_usage_alert_threshold}%"

    condition_threshold {
      filter          = "metric.type=\"agent.googleapis.com/disk/percent_used\" AND resource.type=\"gce_instance\" AND resource.labels.instance_id=\"${google_compute_instance.postgres.instance_id}\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = var.disk_usage_alert_threshold

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = var.alert_notification_channels

  alert_strategy {
    auto_close = "86400s"
  }
}

# =============================================================================
# Secret Version Sync (Ensures Secrets Match VM Configuration)
# =============================================================================
# This resource ensures Secret Manager secrets are updated with the actual
# values from the VM. This prevents the issue where Terraform variables and
# Secret Manager get out of sync (e.g., database name changes on VM recreation).
#
# The trigger ensures this runs after VM is created/recreated.

resource "null_resource" "sync_secrets" {
  triggers = {
    # Re-run when these values change
    db_name = var.postgres_db_name
    db_user = var.postgres_db_user
    db_host = google_compute_address.postgres_ip.address
    # Also trigger on VM instance ID to catch recreation
    instance_id = google_compute_instance.postgres.id
  }

  # Use local-exec to update Secret Manager with current values
  # NOTE: Using printf instead of echo/<<< to avoid trailing newline issues
  provisioner "local-exec" {
    command = <<-EOT
      echo "Syncing Secret Manager secrets with VM configuration..."
      # Update DB name secret - use printf to avoid trailing newline
      printf '%s' "${var.postgres_db_name}" | gcloud secrets versions add ${google_secret_manager_secret.postgres_db.secret_id} \
        --project=${var.project_id} --data-file=-
      # Update DB user secret
      printf '%s' "${var.postgres_db_user}" | gcloud secrets versions add ${google_secret_manager_secret.postgres_user.secret_id} \
        --project=${var.project_id} --data-file=-
      # Update DB host secret (IP may change on recreation)
      printf '%s' "${google_compute_address.postgres_ip.address}" | gcloud secrets versions add ${google_secret_manager_secret.postgres_host.secret_id} \
        --project=${var.project_id} --data-file=-
      # Update DB password secret
      printf '%s' "${var.postgres_db_password}" | gcloud secrets versions add ${google_secret_manager_secret.postgres_password.secret_id} \
        --project=${var.project_id} --data-file=-
      echo "✓ Secrets synced successfully"

      # Verify no trailing newlines in secret (validation)
      echo "Validating secrets..."
      for secret in ${google_secret_manager_secret.postgres_host.secret_id} ${google_secret_manager_secret.postgres_db.secret_id} ${google_secret_manager_secret.postgres_user.secret_id}; do
        value=$(gcloud secrets versions access latest --secret="$secret" --project=${var.project_id})
        if echo "$value" | grep -q $'\n'; then
          echo "ERROR: Secret $secret contains trailing newline!"
          exit 1
        fi
      done
      echo "✓ Secret validation passed (no trailing newlines)"
    EOT

    interpreter = ["bash", "-c"]
  }

  depends_on = [
    google_compute_instance.postgres,
    google_secret_manager_secret_version.postgres_db,
    google_secret_manager_secret_version.postgres_user,
    google_secret_manager_secret_version.postgres_host
  ]
}
