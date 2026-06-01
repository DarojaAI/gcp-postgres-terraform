# Complete Example: Cloud Run + PostgreSQL with gcp-postgres-terraform
#
# This shows the recommended integration pattern:
# 1. Import gcp-postgres-terraform as a git module
# 2. Add your application resources (Cloud Run, etc.)
# 3. Wire them together with outputs

terraform {
  required_version = "~> 1.15.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0, < 8.0"
    }
  }

  backend "gcs" {
    bucket = "myapp-terraform-state"
    prefix = "postgres"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# ---------------------------------------------------------------------------
# PostgreSQL Module
# ---------------------------------------------------------------------------
module "postgres" {
  source = "github.com/DarojaAI/gcp-postgres-terraform//terraform?ref=v1.27.0"

  project_id           = var.project_id
  instance_name        = var.postgres_instance_name
  repo_prefix          = var.repo_prefix
  environment          = var.environment
  region               = var.region
  zone                 = var.zone
  postgres_version     = var.postgres_version
  postgres_db_name     = var.postgres_db_name
  postgres_db_user     = var.postgres_db_user
  postgres_db_password = var.postgres_db_password
  machine_type         = var.postgres_machine_type
  pgvector_enabled     = var.pgvector_enabled
  github_actions_enabled = true
  github_repo          = var.github_repo

  # VPC configuration (uses vpc-infra module internally)
  subnet_cidr    = var.subnet_cidr
  connector_cidr = var.connector_cidr

  # Storage
  disk_size_gb   = var.disk_size_gb
  backup_enabled = var.backup_enabled

  # Schema injection at provisioning time
  init_sql = fileexists("${path.module}/schemas/init.sql") ? file("${path.module}/schemas/init.sql") : null
}

# ---------------------------------------------------------------------------
# Example: Cloud Run service that connects to PostgreSQL
# ---------------------------------------------------------------------------
resource "google_cloud_run_v2_service" "app" {
  name     = "${var.repo_prefix}-${var.environment}-app"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = module.postgres.cloud_run_service_account_email

    vpc_access {
      connector = module.postgres.vpc_connector_id
      egress    = "ALL_TRAFFIC"
    }

    containers {
      image = var.app_image

      env {
        name  = "POSTGRES_HOST"
        value = module.postgres.internal_ip
      }
      env {
        name  = "POSTGRES_DB"
        value = var.postgres_db_name
      }
      env {
        name  = "POSTGRES_USER"
        value = var.postgres_db_user
      }
      env {
        name = "POSTGRES_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = module.postgres.secret_ids["password"]
            version = "latest"
          }
        }
      }
    }
  }

  depends_on = [module.postgres]
}

# Allow unauthenticated access (for demo — restrict in production)
resource "google_cloud_run_v2_service_iam_member" "public" {
  location = var.region
  name     = google_cloud_run_v2_service.app.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
