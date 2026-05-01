# PR5 — Force Data Disk Usage Specification

## Overview
Configure PostgreSQL to store its data directory on the persistent data disk (`/mnt/postgres-data/pg_data`) instead of the boot disk. This prevents boot disk exhaustion and ensures data persists on the dedicated data disk.

## Problem
The init script mounts a persistent data disk to `/mnt/postgres-data` but PostgreSQL continues using the default location on the boot disk (`/var/lib/postgresql/{version}/main`). The data disk is mounted but never used.

## Solution
Pre-seed PostgreSQL's cluster configuration to use the data disk **before** installation, using Option A from the design.

## Implementation

### Step Reordering
Move **Step 5 (Format and Mount Data Disk)** to execute **before** **Step 3 (Install PostgreSQL)**. The data disk must be mounted and the directory must exist before PostgreSQL is installed.

### Pre-seed Configuration
After adding the PostgreSQL repository (Step 2) but before installing PostgreSQL (Step 3), create `/etc/postgresql-common/createcluster.conf`:

```bash
mkdir -p /etc/postgresql-common
cat > /etc/postgresql-common/createcluster.conf << EOF
# Default data directory for new PostgreSQL clusters
data_directory = '/mnt/postgres-data/pg_data'
EOF
chmod 644 /etc/postgresql-common/createcluster.conf
```

This configures the PostgreSQL package to place data in the persistent disk location during initial cluster creation.

### Updated Step Sequence

| Step | Action |
|------|--------|
| 1 | System Updates |
| 2 | Add PostgreSQL Repository |
| 2b | **NEW** Pre-seed createcluster.conf |
| 3 | **MOVED** Format and Mount Data Disk |
| 4 | Install PostgreSQL (now uses data disk) |
| 5-13 | Remaining steps (renumbered) |

### Verification
Add a health check in Step 13 to verify the data directory:

```bash
echo "[$(date -Iseconds)] Health Check: Verify data directory..."
DATA_DIR=$(sudo -u postgres psql -t -c "SHOW data_directory;" 2>&1 | tr -d ' ')
if [[ "$DATA_DIR" == "/mnt/postgres-data/pg_data" ]]; then
  echo "[$(date -Iseconds)] ✅ PostgreSQL using data disk: $DATA_DIR"
else
  echo "[$(date -Iseconds)] ❌ PostgreSQL NOT using data disk! Current: $DATA_DIR"
  echo "[$(date -Iseconds)] Expected: /mnt/postgres-data/pg_data"
  exit 1
fi
```

## Files Modified
- `terraform/scripts/postgres_init.sh`

## Breaking Change
This is a **breaking change**. Existing deployments will recreate the VM and lose data. Users must:
1. Take pg_dump backup before applying
2. Apply the update (VM recreated)
3. Restore from backup

Document in release notes / CHANGELOG.

## Test Plan
1. Deploy to dev environment
2. SSH into VM
3. Run `sudo -u postgres psql -c "SHOW data_directory;"`
4. Verify it returns `/mnt/postgres-data/pg_data`
5. Check `df -h` confirms data disk has activity