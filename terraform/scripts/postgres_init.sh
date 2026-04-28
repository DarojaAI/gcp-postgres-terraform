#!/bin/bash
# =============================================================================
# PostgreSQL Initialization Script for GCP Compute Engine
# =============================================================================
# This script runs on first boot to install and configure PostgreSQL with
# optional pgvector extension.
#
# Usage: This script is called by the Terraform metadata_startup_script.
# All configuration comes from Terraform template variables.
#
# CRITICAL: This script must exit with status 0 on success or non-zero on failure.
# Failures are visible in GCP Cloud Logging and trigger validation alerts.
#
# =============================================================================

set -euo pipefail

# Logging setup - capture all output with timestamps
LOG_FILE="/var/log/postgres-setup.log"
exec 1> >(tee -a "$LOG_FILE")
exec 2> >(tee -a "$LOG_FILE" >&2)

# Template variables (injected by Terraform)
DB_NAME="${db_name}"
DB_USER="${db_user}"
DB_PASSWORD="${db_password}"
POSTGRES_VERSION="${postgres_version}"
BACKUP_BUCKET="${backup_bucket}"
DATA_DISK_DEVICE="${data_disk_device}"
PGVECTOR_ENABLED="${pgvector_enabled}"
INIT_SQL="${init_sql}"
MAX_CONNECTIONS="${max_connections}"
SHARED_BUFFERS="${shared_buffers}"
WORK_MEM="${work_mem}"
MAINTENANCE_WORK_MEM="${maintenance_work_mem}"
INTERNAL_IP="${internal_ip}"
MOUNT_POINT="/mnt/postgres-data"

echo "[$(date -Iseconds)] ========================================="
echo "[$(date -Iseconds)] PostgreSQL Setup Starting"
echo "[$(date -Iseconds)] ========================================="
echo "[$(date -Iseconds)] Timestamp: $(date)"
echo "[$(date -Iseconds)] DB_NAME: $DB_NAME"
echo "[$(date -Iseconds)] DB_USER: $DB_USER"
echo "[$(date -Iseconds)] POSTGRES_VERSION: $POSTGRES_VERSION"
echo "[$(date -Iseconds)] PGVECTOR_ENABLED: $PGVECTOR_ENABLED"
echo "[$(date -Iseconds)] DATA_DISK_DEVICE: /dev/$DATA_DISK_DEVICE"
echo "[$(date -Iseconds)] LOG_FILE: $LOG_FILE"
echo ""

# ============================================
# Step 1: System Updates
# ============================================
echo "[$(date -Iseconds)] ===== Step 1: System Updates ====="
echo "[$(date -Iseconds)] Updating package lists..."
apt-get update || { 
  echo "[$(date -Iseconds)] ERROR: apt-get update failed"; 
  exit 1; 
}

echo "[$(date -Iseconds)] Upgrading packages..."
apt-get upgrade -y || { 
  echo "[$(date -Iseconds)] ERROR: apt-get upgrade failed"; 
  exit 1; 
}
echo "[$(date -Iseconds)] ✅ System updated successfully"

# ============================================
# Step 2: Add PostgreSQL Repository
# ============================================
echo "[$(date -Iseconds)] ===== Step 2: Add PostgreSQL Repository ====="
apt-get install -y lsb-release curl gnupg2 || {
  echo "[$(date -Iseconds)] ERROR: Failed to install prerequisites"
  exit 1
}

curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | tee /usr/share/keyrings/postgresql-archive-keyring.gpg >/dev/null || {
  echo "[$(date -Iseconds)] ERROR: Failed to add PostgreSQL GPG key"
  exit 1
}

echo "deb [signed-by=/usr/share/keyrings/postgresql-archive-keyring.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" | tee /etc/apt/sources.list.d/postgresql.list

echo "[$(date -Iseconds)] Updating package lists with PostgreSQL repository..."
apt-get update || {
  echo "[$(date -Iseconds)] ERROR: apt-get update failed after adding PostgreSQL repo"
  exit 1
}
echo "[$(date -Iseconds)] ✅ PostgreSQL repository added successfully"

# ============================================
# Step 3: Install PostgreSQL
# ============================================
echo "[$(date -Iseconds)] ===== Step 3: Install PostgreSQL ====="
echo "[$(date -Iseconds)] Installing PostgreSQL $POSTGRES_VERSION..."
apt-get install -y "postgresql-$POSTGRES_VERSION" "postgresql-contrib-$POSTGRES_VERSION" || {
  echo "[$(date -Iseconds)] ERROR: PostgreSQL installation failed"
  exit 1
}

# Verify installation
if ! command -v psql &>/dev/null; then
  echo "[$(date -Iseconds)] ERROR: psql command not found after installation"
  exit 1
fi

PG_VERSION=$(psql --version)
echo "[$(date -Iseconds)] ✅ PostgreSQL installed successfully"
echo "[$(date -Iseconds)] Version: $PG_VERSION"

# ============================================
# Step 4: Install pgvector (if enabled)
# ============================================
if [[ "$PGVECTOR_ENABLED" == "true" ]] || [[ "$PGVECTOR_ENABLED" == "1" ]]; then
  echo "[$(date -Iseconds)] ===== Step 4: Install pgvector ====="
  echo "[$(date -Iseconds)] Installing pgvector extension..."
  apt-get install -y "postgresql-$POSTGRES_VERSION-pgvector" || {
    echo "[$(date -Iseconds)] ERROR: pgvector installation failed"
    exit 1
  }
  echo "[$(date -Iseconds)] ✅ pgvector installed successfully"
else
  echo "[$(date -Iseconds)] ===== Step 4: pgvector SKIPPED (disabled) ====="
fi

# ============================================
# Step 5: Format and Mount Data Disk
# ============================================
echo "[$(date -Iseconds)] ===== Step 5: Format and Mount Data Disk ====="
if [[ -b /dev/$DATA_DISK_DEVICE ]]; then
  echo "[$(date -Iseconds)] Found data disk: /dev/$DATA_DISK_DEVICE"
  
  if ! grep -q "/dev/$DATA_DISK_DEVICE" /etc/fstab 2>/dev/null; then
    echo "[$(date -Iseconds)] Formatting disk /dev/$DATA_DISK_DEVICE..."
    mkfs.ext4 -F "/dev/$DATA_DISK_DEVICE" || {
      echo "[$(date -Iseconds)] ERROR: Failed to format disk /dev/$DATA_DISK_DEVICE"
      exit 1
    }
    
    echo "[$(date -Iseconds)] Creating mount point: $MOUNT_POINT"
    mkdir -p "$MOUNT_POINT"
    
    echo "[$(date -Iseconds)] Adding to /etc/fstab"
    echo "/dev/$DATA_DISK_DEVICE $MOUNT_POINT ext4 defaults,nofail 0 0" >> /etc/fstab
    
    echo "[$(date -Iseconds)] Mounting disk..."
    mount "$MOUNT_POINT" || {
      echo "[$(date -Iseconds)] ERROR: Failed to mount $MOUNT_POINT"
      exit 1
    }
    
    echo "[$(date -Iseconds)] ✅ Disk mounted successfully"
  else
    echo "[$(date -Iseconds)] ℹ️  Disk already mounted"
  fi
  
  # Verify mount
  if ! mountpoint -q "$MOUNT_POINT"; then
    echo "[$(date -Iseconds)] ERROR: Mount point $MOUNT_POINT is not accessible"
    exit 1
  fi
else
  echo "[$(date -Iseconds)] ⚠️  Data disk /dev/$DATA_DISK_DEVICE not found"
  echo "[$(date -Iseconds)] PostgreSQL will use boot disk (not recommended for production)"
fi

# ============================================
# Step 6: Configure PostgreSQL Data Directory
# ============================================
echo "[$(date -Iseconds)] ===== Step 6: Configure PostgreSQL Data Directory ====="
if [[ -d "$MOUNT_POINT" ]]; then
  echo "[$(date -Iseconds)] Configuring PostgreSQL data directory on persistent disk..."
  PG_DATA_DIR="$MOUNT_POINT/pg_data"
  mkdir -p "$PG_DATA_DIR"
  chown -R postgres:postgres "$MOUNT_POINT"
  chmod 700 "$PG_DATA_DIR"
  echo "[$(date -Iseconds)] ✅ Data directory configured: $PG_DATA_DIR"
else
  echo "[$(date -Iseconds)] ⚠️  Mount point not available, using default location"
fi

# ============================================
# Step 7: Configure PostgreSQL
# ============================================
echo "[$(date -Iseconds)] ===== Step 7: Configure PostgreSQL ====="
echo "[$(date -Iseconds)] Updating postgresql.conf..."

cat >> "/etc/postgresql/$POSTGRES_VERSION/main/postgresql.conf" << EOF

# ===== EAI Custom Configuration =====
# Performance tuning
max_connections = $MAX_CONNECTIONS
shared_buffers = $SHARED_BUFFERS
effective_cache_size = 2GB
work_mem = $WORK_MEM
maintenance_work_mem = $MAINTENANCE_WORK_MEM
random_page_cost = 1.1
effective_io_concurrency = 200

# Extensions
$(if [[ "$PGVECTOR_ENABLED" == "true" ]] || [[ "$PGVECTOR_ENABLED" == "1" ]]; then echo "shared_preload_libraries = 'pgvector'"; fi)

# Logging
log_statement = 'all'
log_duration = true
log_min_duration_statement = 1000
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '

# Network
listen_addresses = '*'
EOF

echo "[$(date -Iseconds)] ✅ PostgreSQL configuration updated"

# ============================================
# Step 8: Start PostgreSQL Service
# ============================================
echo "[$(date -Iseconds)] ===== Step 8: Start PostgreSQL Service ====="
echo "[$(date -Iseconds)] Starting PostgreSQL service..."
systemctl start "postgresql@$POSTGRES_VERSION-main" || {
  echo "[$(date -Iseconds)] ERROR: Failed to start PostgreSQL"
  echo "[$(date -Iseconds)] Service status:"
  systemctl status "postgresql@$POSTGRES_VERSION-main" || true
  echo "[$(date -Iseconds)] Recent logs:"
  journalctl -u "postgresql@$POSTGRES_VERSION-main" -n 50 || true
  exit 1
}

echo "[$(date -Iseconds)] Enabling PostgreSQL service..."
systemctl enable "postgresql@$POSTGRES_VERSION-main" || {
  echo "[$(date -Iseconds)] ERROR: Failed to enable PostgreSQL service"
  exit 1
}

# Wait for service to stabilize
echo "[$(date -Iseconds)] Waiting for PostgreSQL to stabilize..."
sleep 3

# Verify service is running
if ! systemctl is-active --quiet "postgresql@$POSTGRES_VERSION-main"; then
  echo "[$(date -Iseconds)] ERROR: PostgreSQL service is not running after startup"
  echo "[$(date -Iseconds)] Service status:"
  systemctl status "postgresql@$POSTGRES_VERSION-main" || true
  echo "[$(date -Iseconds)] Recent logs:"
  journalctl -u "postgresql@$POSTGRES_VERSION-main" -n 100 || true
  exit 1
fi

echo "[$(date -Iseconds)] ✅ PostgreSQL service started and enabled"

# ============================================
# Step 9: Enable Extensions
# ============================================
echo "[$(date -Iseconds)] ===== Step 9: Enable Extensions ====="
if [[ "$PGVECTOR_ENABLED" == "true" ]] || [[ "$PGVECTOR_ENABLED" == "1" ]]; then
  echo "[$(date -Iseconds)] Enabling pgvector extension..."
  sudo -u postgres psql -c "CREATE EXTENSION IF NOT EXISTS pgvector;" || {
    echo "[$(date -Iseconds)] ERROR: Failed to create pgvector extension"
    exit 1
  }
  echo "[$(date -Iseconds)] ✅ pgvector extension enabled"
fi

# Enable common extensions
echo "[$(date -Iseconds)] Enabling common extensions..."
sudo -u postgres psql << SQL || {
  echo "[$(date -Iseconds)] ERROR: Failed to enable extensions"
  exit 1
}
CREATE EXTENSION IF NOT EXISTS uuid-ossp;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS hstore;
SQL
echo "[$(date -Iseconds)] ✅ Common extensions enabled"

# ============================================
# Step 10: Create Database and User
# ============================================
echo "[$(date -Iseconds)] ===== Step 10: Create Database and User ====="
echo "[$(date -Iseconds)] Creating database '$DB_NAME' and user '$DB_USER'..."

sudo -u postgres psql << SQL || {
  echo "[$(date -Iseconds)] ERROR: Failed to create database or user"
  exit 1
}
CREATE DATABASE "$DB_NAME";
CREATE USER "$DB_USER" WITH PASSWORD '$DB_PASSWORD';
ALTER ROLE "$DB_USER" SET search_path = public;
GRANT CONNECT ON DATABASE "$DB_NAME" TO "$DB_USER";
GRANT USAGE ON SCHEMA public TO "$DB_USER";
GRANT CREATE ON SCHEMA public TO "$DB_USER";
GRANT ALL PRIVILEGES ON DATABASE "$DB_NAME" TO "$DB_USER";
SQL

echo "[$(date -Iseconds)] ✅ Database and user created"

# ============================================
# Step 11: Run Custom Init SQL (if provided)
# ============================================
if [[ -n "$INIT_SQL" ]] && [[ "$INIT_SQL" != "null" ]]; then
  echo "[$(date -Iseconds)] ===== Step 11: Run Custom Init SQL ====="
  echo "[$(date -Iseconds)] Executing custom initialization SQL..."
  sudo -u postgres psql -d "$DB_NAME" << SQL || {
    echo "[$(date -Iseconds)] ERROR: Failed to execute custom init SQL"
    exit 1
  }
  $INIT_SQL
SQL
  echo "[$(date -Iseconds)] ✅ Custom init SQL completed"
fi

# ============================================
# Step 12: Setup Backups (if bucket provided)
# ============================================
if [[ -n "$BACKUP_BUCKET" ]] && [[ "$BACKUP_BUCKET" != "null" ]]; then
  echo "[$(date -Iseconds)] ===== Step 12: Setup Backups ====="
  echo "[$(date -Iseconds)] Installing pgBackRest for backups..."
  apt-get install -y pgbackrest || {
    echo "[$(date -Iseconds)] ERROR: Failed to install pgbackrest"
    exit 1
  }
  
  echo "[$(date -Iseconds)] Configuring pgBackRest..."
  cat > "/etc/pgbackrest.conf" << PGBACKREST_EOF
[global]
repo1-type=s3
repo1-s3-bucket=$BACKUP_BUCKET
repo1-s3-region=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/zone" -H "Metadata-Flavor: Google" | cut -d'/' -f4 | sed 's/-[a-z]$//')

[stanza:postgres-$POSTGRES_VERSION]
db-path=/var/lib/postgresql/$POSTGRES_VERSION/main
db-port=5432
db-user=postgres

log-level-console=info
log-level-file=debug
log-path=/var/log/pgbackrest
PGBACKREST_EOF

  mkdir -p /var/log/pgbackrest
  chown postgres:postgres /var/log/pgbackrest
  chmod 750 /var/log/pgbackrest
  
  echo "[$(date -Iseconds)] ✅ pgBackRest configured"
fi

# ============================================
# Step 13: Health Checks
# ============================================
echo "[$(date -Iseconds)] ===== Step 13: Health Checks ====="
echo "[$(date -Iseconds)] Running final health checks..."

# Check 1: PostgreSQL responds to version query
echo "[$(date -Iseconds)] Health Check 1: PostgreSQL version query..."
PG_VERSION_OUTPUT=$(sudo -u postgres psql -c "SELECT version();" 2>&1)
if [[ "$PG_VERSION_OUTPUT" == *"PostgreSQL"* ]]; then
  echo "[$(date -Iseconds)] ✅ PostgreSQL responding to queries"
  echo "[$(date -Iseconds)] $PG_VERSION_OUTPUT"
else
  echo "[$(date -Iseconds)] ❌ PostgreSQL version query failed"
  echo "[$(date -Iseconds)] Output: $PG_VERSION_OUTPUT"
  exit 1
fi

# Check 2: Database exists and is accessible
echo "[$(date -Iseconds)] Health Check 2: Database accessibility..."
DB_CHECK=$(sudo -u postgres psql -d "$DB_NAME" -c "SELECT 1;" 2>&1)
if [[ "$DB_CHECK" == *"1"* ]]; then
  echo "[$(date -Iseconds)] ✅ Database '$DB_NAME' is accessible"
else
  echo "[$(date -Iseconds)] ❌ Database connectivity check failed"
  exit 1
fi

# Check 3: User can connect
echo "[$(date -Iseconds)] Health Check 3: Application user connectivity..."
USER_CHECK=$(PGPASSWORD="$DB_PASSWORD" psql -h localhost -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" 2>&1)
if [[ "$USER_CHECK" == *"1"* ]]; then
  echo "[$(date -Iseconds)] ✅ Application user '$DB_USER' can connect"
else
  echo "[$(date -Iseconds)] ⚠️  Application user connectivity check inconclusive (may fail if using socket auth)"
fi

# Check 4: Extensions are installed (if pgvector enabled)
if [[ "$PGVECTOR_ENABLED" == "true" ]] || [[ "$PGVECTOR_ENABLED" == "1" ]]; then
  echo "[$(date -Iseconds)] Health Check 4: pgvector extension..."
  EXT_CHECK=$(sudo -u postgres psql -c "SELECT * FROM pg_extension WHERE extname = 'pgvector';" 2>&1)
  if [[ "$EXT_CHECK" == *"pgvector"* ]] || [[ "$EXT_CHECK" == *"1 row"* ]]; then
    echo "[$(date -Iseconds)] ✅ pgvector extension is installed"
  else
    echo "[$(date -Iseconds)] ⚠️  pgvector extension status unclear"
  fi
fi

# ============================================
# Completion
# ============================================
echo ""
echo "[$(date -Iseconds)] ================================================================"
echo "[$(date -Iseconds)] ✅ PostgreSQL Setup COMPLETED SUCCESSFULLY"
echo "[$(date -Iseconds)] ================================================================"
echo "[$(date -Iseconds)] Summary:"
echo "[$(date -Iseconds)]   PostgreSQL Version: $POSTGRES_VERSION"
echo "[$(date -Iseconds)]   Database: $DB_NAME"
echo "[$(date -Iseconds)]   User: $DB_USER"
echo "[$(date -Iseconds)]   Port: 5432"
echo "[$(date -Iseconds)]   Mount Point: $MOUNT_POINT"
echo "[$(date -Iseconds)]   pgvector Enabled: $PGVECTOR_ENABLED"
echo "[$(date -Iseconds)]   Log File: $LOG_FILE"
echo "[$(date -Iseconds)] ================================================================"
echo "[$(date -Iseconds)] Next steps:"
echo "[$(date -Iseconds)]   1. Verify database connectivity from application"
echo "[$(date -Iseconds)]   2. Run health check validation workflow"
echo "[$(date -Iseconds)]   3. Monitor logs at: $LOG_FILE"
echo "[$(date -Iseconds)] ================================================================"

exit 0
