# PR5 — Force Data Disk Usage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Configure PostgreSQL to store data on the persistent data disk (`/mnt/postgres-data/pg_data`) instead of the boot disk by pre-seeding the cluster configuration before installation.

**Architecture:** Modify the init script to:
1. Pre-seed `/etc/postgresql-common/createcluster.conf` before PostgreSQL install
2. Move data disk mounting to happen BEFORE PostgreSQL installation
3. Add verification health check

**Tech Stack:** Bash script, Terraform templatefile, PostgreSQL postgresql-common

---

## Task 1: Modify postgres_init.sh — Add pre-seed config and reorder steps

**Files:**
- Modify: `terraform/scripts/postgres_init.sh`

### Step 1: Read current init script to understand exact line numbers

```bash
# Read terraform/scripts/postgres_init.sh and identify:
# - Line numbers for Step 2 (Add PostgreSQL Repository) - where to add Step 2b
# - Line numbers for Step 3 (Install PostgreSQL)
# - Line numbers for Step 5 (Format and Mount Data Disk) - to be moved before Step 3
# - Line numbers for Step 13 (Health Checks) - where to add verification
```

### Step 2: Add Step 2b — Pre-seed createcluster.conf

After the PostgreSQL repository is added (around line 82-89, after the apt-get update that adds the repo), add:

```bash
# ============================================
# Step 2b: Pre-seed PostgreSQL cluster config
# ============================================
echo "[$(date -Iseconds)] ===== Step 2b: Pre-seed PostgreSQL cluster config ====="
mkdir -p /etc/postgresql-common
cat > /etc/postgresql-common/createcluster.conf << EOF
# Default data directory for new PostgreSQL clusters
data_directory = '/mnt/postgres-data/pg_data'
EOF
chmod 644 /etc/postgresql-common/createcluster.conf
echo "[$(date -Iseconds)] ✅ PostgreSQL cluster config pre-seeded"
```

### Step 3: Move Step 5 (Format and Mount Data Disk) to BEFORE Step 3

**Current order:**
- Step 3: Install PostgreSQL
- Step 5: Format and Mount Data Disk

**New order:**
- Step 3: Format and Mount Data Disk (moved here)
- Step 4: Install PostgreSQL

Cut the entire Step 5 block (lines ~127-165) and paste it AFTER Step 2b but BEFORE the current Step 3 "Install PostgreSQL" section.

### Step 4: Renumber all subsequent steps

After moving Step 5 to be the new Step 3, increment all step numbers:
- Old Step 3 → New Step 4 (Install PostgreSQL)
- Old Step 4 → New Step 5 (Install pgvector)
- Old Step 5 (now moved) → New Step 3 (Format and Mount Data Disk)
- Old Step 6 → New Step 7 (Configure Data Directory)
- Old Step 7 → New Step 8 (Configure PostgreSQL)
- Old Step 8 → New Step 9 (Start Service)
- Old Step 9 → New Step 10 (Enable Extensions)
- Old Step 10 → New Step 11 (Create DB and User)
- Old Step 11 → New Step 12 (Custom Init SQL)
- Old Step 12 → New Step 13 (Setup Backups)
- Old Step 13 → New Step 14 (Health Checks)

### Step 5: Add health check verification in final Health Checks section

In the Health Checks section (now Step 14), add after the existing checks:

```bash
# Check 5: Verify data directory is on persistent disk
echo "[$(date -Iseconds)] Health Check 5: Verify data directory on persistent disk..."
DATA_DIR=$(sudo -u postgres psql -t -c "SHOW data_directory;" 2>&1 | tr -d ' ')
if [[ "$DATA_DIR" == "/mnt/postgres-data/pg_data" ]]; then
  echo "[$(date -Iseconds)] ✅ PostgreSQL using data disk: $DATA_DIR"
else
  echo "[$(date -Iseconds)] ❌ PostgreSQL NOT using data disk! Current: $DATA_DIR"
  echo "[$(date -Iseconds)] Expected: /mnt/postgres-data/pg_data"
  exit 1
fi
```

---

## Task 2: Validate changes

**Files:**
- Test: `terraform/scripts/postgres_init.sh`

### Step 6: Run terraform fmt

```bash
terraform fmt -check -diff terraform/scripts/postgres_init.sh
```

If it fails, run `terraform fmt terraform/scripts/postgres_init.sh` to fix.

### Step 7: Run terraform validate

```bash
cd terraform && terraform init -backend=false && terraform validate
```

Expected: `Success! The configuration is valid.`

---

## Task 3: Commit changes

### Step 8: Create commit

```bash
git add terraform/scripts/postgres_init.sh
git commit -m "feat!: force PostgreSQL data directory to persistent disk

- Pre-seed /etc/postgresql-common/createcluster.conf before install
- Move data disk mounting to run before PostgreSQL installation
- Add health check to verify data_directory points to /mnt/postgres-data/pg_data

BREAKING CHANGE: Existing deployments will lose data on apply.
Users must backup before applying and restore after.

Implements PR5 from ROBUSTNESS-PLAN.md"
```

---

## Verification Checklist

After implementation, verify:
- [ ] `terraform fmt` passes with no diff
- [ ] `terraform validate` passes
- [ ] Init script has Step 2b that creates createcluster.conf
- [ ] Data disk mounting (Step 3) comes before Install PostgreSQL (Step 4)
- [ ] Health check verifies data_directory returns /mnt/postgres-data/pg_data
- [ ] All step numbers are sequential and correct