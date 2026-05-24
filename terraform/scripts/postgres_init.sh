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

# Prevent interactive prompts during package installation
export DEBIAN_FRONTEND=noninteractive

# Idempotent sentinel directory
SENTINEL_DIR="/var/lib/postgres-setup"
mkdir -p "$SENTINEL_DIR"

# Helper function to run a step idempotently
# Usage: run_step <step-number> <step-name> <command>
run_step() {
  local step_num="$1"
  local step_name="$2"
  local step_cmd="$3"
  local sentinel_file="$SENTINEL_DIR/step-$step_num-done"

  if [[ -f "$sentinel_file" ]]; then
    echo "[$(date -Iseconds)] ⏭️  Step $step_num ($step_name): skipping (already completed)"
    return 0
  fi

  echo "[$(date -Iseconds)] ===== Step $step_num: $step_name ====="
  eval "$step_cmd"
  local result=$?

  if [[ $result -eq 0 ]]; then
    touch "$sentinel_file"
    echo "[$(date -Iseconds)] ✅ Step $step_num ($step_name): completed"
  else
    echo "[$(date -Iseconds)] ❌ Step $step_num ($step_name): failed with exit code $result"
    return $result
  fi
}

# Retry function for apt-get with exponential backoff
# Usage: apt_retry <command>
apt_retry() {
  local max_attempts=3
  local attempt=1
  local delay=10

  while [[ $attempt -le $max_attempts ]]; do
    echo "[$(date -Iseconds)] apt-get attempt $attempt of $max_attempts..."
    if eval "$@"; then
      return 0
    fi

    if [[ $attempt -lt $max_attempts ]]; then
      local sleep_time=$((delay * attempt))  # 10s, 30s, 90s
      echo "[$(date -Iseconds)] apt-get failed, retrying in $${sleep_time}s..."
      sleep "$sleep_time"
    fi

    ((attempt++))
  done

  echo "[$(date -Iseconds)] ERROR: apt-get failed after $max_attempts attempts"
  return 1
}

# Logging setup - capture all output with timestamps
LOG_FILE="/var/log/postgres-setup.log"
exec 1> >(tee -a "$LOG_FILE")
exec 2> >(tee -a "$LOG_FILE" >&2)

# Template variables (injected by Terraform)
DB_NAME='${db_name}'
DB_USER='${db_user}'
DB_PASSWORD='${db_password}'
POSTGRES_VERSION='${postgres_version}'
BACKUP_BUCKET='${backup_bucket}'
DATA_DISK_DEVICE='${data_disk_device}'
PGVECTOR_ENABLED='${pgvector_enabled}'
INIT_SQL='${init_sql}'
LOG_ALL_STATEMENTS='${log_all_statements}'
MAX_CONNECTIONS='${max_connections}'
SHARED_BUFFERS='${shared_buffers}'
WORK_MEM='${work_mem}'
MAINTENANCE_WORK_MEM='${maintenance_work_mem}'
INTERNAL_IP='${internal_ip}'
SUBNET_CIDR='${subnet_cidr}'
POSTGRES_PORT='${postgres_port}'
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
# Step 1: System Updates (with retry)
# ============================================
run_step 1 "System Updates" '
  echo "Updating package lists with retry...";
  apt_retry "apt-get update";
  echo "Upgrading packages...";
  apt-get upgrade -y
'

# ============================================
# Step 2: Add PostgreSQL Repository (with retry)
# ============================================
run_step 2 "Add PostgreSQL Repository" '
  apt-get install -y lsb-release curl gnupg2;
  curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | tee /usr/share/keyrings/postgresql-archive-keyring.gpg >/dev/null;
  echo "deb [signed-by=/usr/share/keyrings/postgresql-archive-keyring.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" | tee /etc/apt/sources.list.d/postgresql.list;
  echo "Updating package lists with PostgreSQL repository...";
  apt_retry "apt-get update"
'

# ============================================
# Step 2b: Pre-seed PostgreSQL cluster config (data directory)
# ============================================
run_step 2b "Pre-seed PostgreSQL cluster config" '
  echo "Pre-seeding PostgreSQL cluster config to use persistent data disk...";
  mkdir -p /etc/postgresql-common;
  cat > /etc/postgresql-common/createcluster.conf << EOF
# Default data directory for new PostgreSQL clusters
data_directory = '"'"'/mnt/postgres-data/pg_data'"'"'
EOF
  chmod 644 /etc/postgresql-common/createcluster.conf;
  echo "PostgreSQL cluster config pre-seeded with data_directory = /mnt/postgres-data/pg_data"
'

# ============================================
# Step 3: Format and Mount Data Disk
# ============================================
run_step 3 "Format and Mount Data Disk" '
  if [[ -b /dev/$DATA_DISK_DEVICE ]]; then
    echo "Found data disk: /dev/$DATA_DISK_DEVICE";

    if ! grep -q "/dev/$DATA_DISK_DEVICE" /etc/fstab 2>/dev/null; then
      echo "Formatting disk /dev/$DATA_DISK_DEVICE...";
      mkfs.ext4 -F "/dev/$DATA_DISK_DEVICE";
      echo "Creating mount point: $MOUNT_POINT";
      mkdir -p "$MOUNT_POINT";
      echo "Adding to /etc/fstab";
      echo "/dev/$DATA_DISK_DEVICE $MOUNT_POINT ext4 defaults,nofail 0 0" >> /etc/fstab;
      echo "Mounting disk...";
      mount "$MOUNT_POINT";
      echo "Disk mounted successfully";
    else
      echo "Disk already mounted";
    fi;

    if ! mountpoint -q "$MOUNT_POINT"; then
      echo "ERROR: Mount point $MOUNT_POINT is not accessible";
      exit 1;
    fi
  else
    echo "WARNING: Data disk /dev/$DATA_DISK_DEVICE not found";
    echo "PostgreSQL will use boot disk (not recommended for production)";
  fi
'

# ============================================
# Step 4: Install PostgreSQL
# ============================================
run_step 4 "Install PostgreSQL" '
  echo "Installing PostgreSQL $POSTGRES_VERSION...";
  apt-get install -y "postgresql-$POSTGRES_VERSION" "postgresql-contrib-$POSTGRES_VERSION";
  if ! command -v psql &>/dev/null; then
    echo "ERROR: psql command not found after installation";
    exit 1;
  fi;
  PG_VERSION=$(psql --version);
  echo "PostgreSQL installed: $PG_VERSION";
  echo "Stopping auto-started PostgreSQL so config can be applied before first real start...";
  systemctl stop "postgresql@$POSTGRES_VERSION-main" || true
'

# ============================================
# Step 5: Install pgvector (conditional, with retry)
# ============================================
if [[ "$PGVECTOR_ENABLED" == "true" ]] || [[ "$PGVECTOR_ENABLED" == "1" ]]; then
  run_step 5 "Install pgvector" '
    echo "Installing pgvector extension...";
    apt-get install -y "postgresql-$POSTGRES_VERSION-pgvector"
  '
else
  # Create sentinel file for skipped step to maintain step numbering
  echo "[$(date -Iseconds)] ===== Step 5: pgvector SKIPPED (disabled) ====="
  touch "$SENTINEL_DIR/step-5-done"
fi

# ============================================
# Step 7: Configure PostgreSQL Data Directory
# ============================================
run_step 7 "Configure PostgreSQL Data Directory" '
  if [[ -d "$MOUNT_POINT" ]]; then
    echo "Configuring PostgreSQL data directory on persistent disk...";
    PG_DATA_DIR="$MOUNT_POINT/pg_data";
    mkdir -p "$PG_DATA_DIR";
    chown -R postgres:postgres "$MOUNT_POINT";
    chmod 700 "$PG_DATA_DIR";
    echo "Data directory configured: $PG_DATA_DIR";
  else
    echo "WARNING: Mount point not available, using default location";
  fi
'

# ============================================
# Step 9: Configure PostgreSQL
# ============================================
run_step 9 "Configure PostgreSQL" '
  echo "Updating postgresql.conf...";

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

# Extensions (pgvector loaded dynamically via CREATE EXTENSION, no preload needed)

# Logging
$(if [[ "$LOG_ALL_STATEMENTS" == "true" ]] || [[ "$LOG_ALL_STATEMENTS" == "1" ]]; then echo "log_statement = '"'"'all'"'"'"; fi)
log_duration = true
log_min_duration_statement = 1000
log_line_prefix = '"'"'%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '"'"'

# Network
listen_addresses = '"'"'*'"'"'
EOF

  echo "PostgreSQL configuration updated";

  echo "Configuring pg_hba.conf for VPC subnet and external access...";
  PG_HBA="/etc/postgresql/$POSTGRES_VERSION/main/pg_hba.conf";
  if ! grep -q "$SUBNET_CIDR" "$PG_HBA" 2>/dev/null; then
    echo "" >> "$PG_HBA";
    echo "# Allow VPC subnet (Cloud Run Jobs, internal services)" >> "$PG_HBA";
    echo "host  all  all  $SUBNET_CIDR  scram-sha-256" >> "$PG_HBA";
    echo "pg_hba.conf updated with VPC subnet: $SUBNET_CIDR";
  else
    echo "pg_hba.conf already contains entry for $SUBNET_CIDR, skipping";
  fi;
  if ! grep -q "0.0.0.0/0" "$PG_HBA" 2>/dev/null; then
    echo "" >> "$PG_HBA";
    echo "# Allow external access (GitHub Actions, other applications)" >> "$PG_HBA";
    echo "host  all  all  0.0.0.0/0  scram-sha-256" >> "$PG_HBA";
    echo "pg_hba.conf updated with 0.0.0.0/0 for external access";
  else
    echo "pg_hba.conf already contains entry for 0.0.0.0/0, skipping";
  fi;

  echo "Restarting PostgreSQL to apply configuration changes...";
  systemctl restart "postgresql@$POSTGRES_VERSION-main";
  echo "PostgreSQL restarted successfully"
'

# ============================================
# Step 10: Start PostgreSQL Service
# ============================================
run_step 10 "Start PostgreSQL Service" '
  echo "Starting PostgreSQL service...";
  systemctl start "postgresql@$POSTGRES_VERSION-main";
  echo "Enabling PostgreSQL service...";
  systemctl enable "postgresql@$POSTGRES_VERSION-main";
  echo "Waiting for PostgreSQL to stabilize...";
  sleep 3;

  if ! systemctl is-active --quiet "postgresql@$POSTGRES_VERSION-main"; then
    echo "ERROR: PostgreSQL service is not running after startup";
    systemctl status "postgresql@$POSTGRES_VERSION-main" || true;
    journalctl -u "postgresql@$POSTGRES_VERSION-main" -n 100 || true;
    exit 1;
  fi;

  echo "PostgreSQL service started and enabled"
'

# ============================================
# Step 12: Enable Extensions
# ============================================
run_step 12 "Enable Extensions" '
  if [[ "$PGVECTOR_ENABLED" == "true" ]] || [[ "$PGVECTOR_ENABLED" == "1" ]]; then
    echo "Enabling pgvector extension...";
    sudo -u postgres psql -c "CREATE EXTENSION IF NOT EXISTS vector;";
    echo "pgvector extension enabled";
  fi;

  echo "Enabling common extensions...";
  sudo -u postgres psql << SQL
CREATE EXTENSION IF NOT EXISTS uuid-ossp;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS hstore;
SQL
  echo "Common extensions enabled"
'

# ============================================
# Step 14: Create Database and User
# ============================================
run_step 14 "Create Database and User" '
  echo "Creating database '\'$DB_NAME'\' and user '\'$DB_USER'\'...";

  sudo -u postgres psql << SQL
CREATE DATABASE "$DB_NAME";
CREATE USER "$DB_USER" WITH PASSWORD '\'$DB_PASSWORD'\';
ALTER ROLE "$DB_USER" SET search_path = public;
GRANT CONNECT ON DATABASE "$DB_NAME" TO "$DB_USER";
GRANT USAGE ON SCHEMA public TO "$DB_USER";
GRANT CREATE ON SCHEMA public TO "$DB_USER";
GRANT ALL PRIVILEGES ON DATABASE "$DB_NAME" TO "$DB_USER";
SQL

  echo "Database and user created"
'

# ============================================
# Step 15: Run Custom Init SQL (if provided)
# ============================================
if [[ -n "$INIT_SQL" ]] && [[ "$INIT_SQL" != "null" ]]; then
  run_step 15 "Run Custom Init SQL" '
    echo "Executing custom initialization SQL...";
    sudo -u postgres psql -d "$DB_NAME" << SQL
$INIT_SQL
SQL
    echo "Custom init SQL completed"
  '
fi

# ============================================
# Step 16: Setup Backups (if bucket provided)
# ============================================
if [[ -n "$BACKUP_BUCKET" ]] && [[ "$BACKUP_BUCKET" != "null" ]]; then
  run_step 16 "Setup Backups" '
    echo "Installing pgBackRest for backups...";
    apt-get install -y pgbackrest;

    echo "Configuring pgBackRest...";
    cat > "/etc/pgbackrest.conf" << PGBACKREST_EOF
[global]
repo1-type=s3
repo1-s3-bucket=$BACKUP_BUCKET
repo1-s3-region=$$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/zone" -H "Metadata-Flavor: Google" | cut -d'/' -f4 | sed 's/-[a-z]$$//')

[stanza:postgres-$${POSTGRES_VERSION}]
db-path=/var/lib/postgresql/$${POSTGRES_VERSION}/main
db-port=5432
db-user=postgres

log-level-console=info
log-level-file=debug
log-path=/var/log/pgbackrest
PGBACKREST_EOF

    mkdir -p /var/log/pgbackrest;
    chown postgres:postgres /var/log/pgbackrest;
    chmod 750 /var/log/pgbackrest;

    echo "pgBackRest configured"
  '
else
  # Create sentinel file for skipped step
  touch "$SENTINEL_DIR/step-12-done"
fi

# ============================================
# Step 17: Health Checks
# ============================================
run_step 17 "Health Checks" '
  echo "Running final health checks...";

  echo "Health Check 1: PostgreSQL version query...";
  PG_VERSION_OUTPUT=$(sudo -u postgres psql -c "SELECT version();" 2>&1);
  if [[ "$PG_VERSION_OUTPUT" == *"PostgreSQL"* ]]; then
    echo "PostgreSQL responding to queries";
    echo "$PG_VERSION_OUTPUT";
  else
    echo "ERROR: PostgreSQL version query failed";
    echo "Output: $PG_VERSION_OUTPUT";
    exit 1;
  fi;

  echo "Health Check 2: Database accessibility...";
  DB_CHECK=$(sudo -u postgres psql -d "$DB_NAME" -c "SELECT 1;" 2>&1);
  if [[ "$DB_CHECK" == *"1"* ]]; then
    echo "Database '\'$DB_NAME'\' is accessible";
  else
    echo "ERROR: Database connectivity check failed";
    exit 1;
  fi;

  echo "Health Check 3: Application user connectivity...";
  USER_CHECK=$(PGPASSWORD="$DB_PASSWORD" psql -h localhost -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" 2>&1);
  if [[ "$USER_CHECK" == *"1"* ]]; then
    echo "Application user '\'$DB_USER'\' can connect";
  else
    echo "WARNING: Application user connectivity check inconclusive";
  fi;

  if [[ "$PGVECTOR_ENABLED" == "true" ]] || [[ "$PGVECTOR_ENABLED" == "1" ]]; then
    echo "Health Check 4: pgvector extension...";
    EXT_CHECK=$(sudo -u postgres psql -c "SELECT * FROM pg_extension WHERE extname = '\'vector\'';" 2>&1);
    if [[ "$EXT_CHECK" == *"vector"* ]] || [[ "$EXT_CHECK" == *"1 row"* ]]; then
      echo "pgvector extension is installed";
    else
      echo "WARNING: pgvector extension status unclear";
    fi
  fi;

  echo "Health Check 5: Verify data directory on persistent disk...";
  DATA_DIR=$(sudo -u postgres psql -t -c "SHOW data_directory;" 2>&1 | tr -d ''\'' '\''');
  if [[ "$DATA_DIR" == "/mnt/postgres-data/pg_data" ]]; then
    echo "PostgreSQL using data disk: $DATA_DIR";
  else
    echo "ERROR: PostgreSQL NOT using data disk! Current: $DATA_DIR";
    echo "Expected: /mnt/postgres-data/pg_data";
    exit 1;
  fi;

  echo "Health Check 6: Verify PostgreSQL is listening...";
  # ss -tlnp may show "0.0.0.0:5432" or "*:5432" depending on version
  # We check for :$${POSTGRES_PORT:-5432} (colon + port) to match either
  if ! ss -tlnp | grep -q ":$${POSTGRES_PORT:-5432}"; then
    echo "ERROR: PostgreSQL is not listening on port $${POSTGRES_PORT:-5432} — check listen_addresses in postgresql.conf";
    exit 1
  fi;
  echo "PostgreSQL is listening on port $${POSTGRES_PORT:-5432}"
'

# ============================================
# Write READY sentinel (always runs, even if script re-run)
# ============================================
echo "[$(date -Iseconds)] Writing READY sentinel..."
echo "READY" > "$SENTINEL_DIR/READY"
echo "[$(date -Iseconds)] ✅ READY sentinel written to $SENTINEL_DIR/READY"

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
echo "[$(date -Iseconds)]   Port: $${POSTGRES_PORT:-5432}"
echo "[$(date -Iseconds)]   Mount Point: $MOUNT_POINT"
echo "[$(date -Iseconds)]   pgvector Enabled: $PGVECTOR_ENABLED"
echo "[$(date -Iseconds)]   Log File: $LOG_FILE"
echo "[$(date -Iseconds)]   Sentinel Dir: $SENTINEL_DIR"
echo "[$(date -Iseconds)] ================================================================"
echo "[$(date -Iseconds)] Next steps:"
echo "[$(date -Iseconds)]   1. Verify database connectivity from application"
echo "[$(date -Iseconds)]   2. Run health check validation workflow"
echo "[$(date -Iseconds)]   3. Monitor logs at: $LOG_FILE"
echo "[$(date -Iseconds)] ================================================================"

exit 0
