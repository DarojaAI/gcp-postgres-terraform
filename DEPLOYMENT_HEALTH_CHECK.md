# Deployment Health Check: Fixing Silent Failures

## Problem Identified

**Startup scripts were failing silently.** When PostgreSQL failed to install on a Compute Engine VM:
- ✅ Terraform apply: SUCCESS (exit code 0)
- ✅ GitHub Actions: PASSED
- ❌ Reality: PostgreSQL was never installed
- ⏰ Detection: 2+ days later (manual discovery)

### Root Cause

The startup script runs inside a Compute Engine VM after creation. If it failed:
1. The VM was still created (so Terraform reported success)
2. The error was buried in GCP startup script logs
3. No post-deployment health check validated the actual state
4. No workflow failure signal alerted the team

---

## Solution: Three-Layer Validation

### Layer 1: Enhanced Startup Script (`postgres_init.sh`)

**Before:**
```bash
set -e
set -x
# Commands proceed even if some fail
apt-get install ...
systemctl start postgresql
# ❌ No verification that PostgreSQL actually started
```

**After:**
```bash
set -euo pipefail  # Fail on ANY error
exec 1> >(tee -a "$LOG_FILE")  # Log everything with timestamps

# Each step has explicit error handling
apt-get install -y postgresql || { echo "ERROR: Installation failed"; exit 1; }

# Health checks after each critical operation
if ! systemctl is-active --quiet postgresql; then
  echo "ERROR: PostgreSQL is not running"
  exit 1
fi
```

**Key Improvements:**
- ✅ `set -euo pipefail` - fail immediately on any error
- ✅ Structured logging with ISO timestamps
- ✅ Error handling for each phase (install, start, verify)
- ✅ Health checks (version query, listening port, extensions)
- ✅ Exits with non-zero code on any failure

**Result:** If PostgreSQL fails to install, the startup script exits immediately with an error code visible in GCP logs.

---

### Layer 2: Auto-Triggered Health Check Workflow

**New File:** `.github/workflows/validate-deployment.yml`

**Triggered automatically** after `terraform-apply.yml` completes.

**Checks (5-point validation):**

1. ✅ **VM Instance Running** - Verify Compute Engine instance status
2. ✅ **PostgreSQL Service Active** - Check systemctl status
3. ✅ **Listening on Port 5432** - Verify network connectivity
4. ✅ **PostgreSQL Responding** - Execute test query (SELECT version())
5. ✅ **Extensions Installed** - Verify pgvector/uuid-ossp available

**If any check fails:**
- ❌ Workflow fails with explicit error message
- 📋 Provides troubleshooting steps
- 🔗 Links to startup script logs
- 🎯 Pinpoints exactly what went wrong

**Output Example (PASS):**
```
✅ DEPLOYMENT VALIDATION SUCCESSFUL

PostgreSQL is fully operational and ready for use.
Version: PostgreSQL 16.2 on x86_64-pc-linux-gnu...
Service: active
Listening: port 5432
Extensions: pgvector, uuid-ossp, pg_trgm
```

**Output Example (FAIL):**
```
❌ DEPLOYMENT VALIDATION FAILED

PostgreSQL is NOT listening on port 5432

ACTION REQUIRED:
1. SSH into instance: gcloud compute ssh postgres-vm-dev --zone=us-central1-b
2. Check logs: sudo tail -100 /var/log/postgres-setup.log
3. Check service: sudo systemctl status postgresql*
4. Re-run workflow: gh workflow run validate-deployment.yml
```

---

### Layer 3: Terraform Workflow Gate

**Updated:** `.github/workflows/terraform-apply.yml`

**Now includes:**
- Explicit warning: "⚠️ DO NOT PROCEED until health check completes"
- Links to health check workflow status
- Deployment marked as "INITIATED (NOT COMPLETE)" until validation passes

---

## Metrics: Before vs After

| Metric | Before | After |
|--------|--------|-------|
| **Time to detect failure** | 2+ days (manual) | ~10 minutes (automatic) |
| **Failure visibility** | Hidden in GCP logs | Explicit workflow failure |
| **Alert mechanism** | None | GitHub Actions notification |
| **Troubleshooting info** | Scattered | All in one workflow output |
| **Recovery steps** | Unknown | Clear instructions provided |

---

## Workflow Sequence

```
1. Push to main or manual trigger
   ↓
2. terraform-apply.yml
   - Creates VPC, Firewall, Compute Engine VM
   - Injects startup script into metadata
   - Terraform reports: SUCCESS
   - Warns: "DO NOT PROCEED until health check"
   ↓
3. VM boots and startup script runs (2-5 minutes)
   - Installs PostgreSQL
   - Enables extensions  
   - Starts service
   - Logs everything to /var/log/postgres-setup.log
   - Exits 0 on success, non-zero on failure
   ↓
4. validate-deployment.yml auto-triggers
   - Waits for VM to be ready
   - Performs 5-point health check
   - Reports PASS or FAIL with details
   ↓
5. Team receives notification
   ✅ PASS:  "PostgreSQL ready, proceed to next step"
   ❌ FAIL:  "PostgreSQL failed to start. SSH in and check logs."
```

---

## How to Use

### For New Deployments

Push to main branch - both workflows run automatically:

```bash
git push origin main
# Terraform Apply runs → creates infrastructure
# Validate Deployment runs → checks PostgreSQL health
```

Watch the workflows:
```bash
gh run list --workflow=terraform-apply.yml
gh run list --workflow=validate-deployment.yml
```

### To Manually Validate Existing Deployment

```bash
# Re-run health check for an environment
gh workflow run validate-deployment.yml -f environment=dev

# Monitor in real-time
gh run watch
```

### To Debug a Failed Deployment

If `validate-deployment.yml` fails:

```bash
# SSH into the VM
gcloud compute ssh postgres-vm-dev --zone=us-central1-b

# Check the startup script log
sudo tail -200 /var/log/postgres-setup.log

# Check if PostgreSQL is installed
dpkg -l | grep postgresql

# Check service status
sudo systemctl status postgresql*

# Check listening ports
sudo ss -tlnp | grep 5432
```

---

## Files Changed

### `gcp-postgres-terraform` Repository

**1. Enhanced Startup Script**
- **File:** `terraform/scripts/postgres_init.sh`
- **Lines:** 426 (was 150)
- **Changes:**
  - Added `set -euo pipefail` for strict error handling
  - Added structured logging with timestamps
  - Added error handling for each step
  - Added 5-phase health checks
  - Added explicit exit codes

**2. New Validation Workflow**
- **File:** `.github/workflows/validate-deployment.yml`
- **New file** (330 lines)
- **Triggers:** Auto on `terraform-apply` completion + manual dispatch
- **Checks:** 5-point health validation
- **Outputs:** PASS/FAIL + troubleshooting

---

## Integration Points

This fix is designed for reuse across projects:

1. **rag-research-tool** - Uses gcp-postgres-terraform as reference module
   - ✅ Updated to use enhanced startup script
   - ✅ Added validation workflow

2. **gcp-postgres-terraform** - Source of truth
   - ✅ Enhanced startup script
   - ✅ Auto-validation workflow
   - ✅ Can be referenced by other projects

---

## Long-term Improvements

Potential enhancements:

1. **Scheduled Health Checks** - Periodic validation ensures PostgreSQL stays healthy
2. **Automated Rollback** - If health check fails, destroy resources and alert team
3. **Slack/Email Alerts** - Notifications for failures
4. **CloudMonitoring Dashboard** - Real-time health status
5. **Data Migration Validation** - Verify dbt/schema migrations complete
6. **Backup Verification** - Test that backups can be restored

---

## Testing the Fix

### Test 1: Verify Startup Script Error Handling

```bash
# Create a test VM with a broken startup script
# The script should exit with error code 1
# GCP will surface this in startup scripts logs
```

### Test 2: Validate Workflow

```bash
# Run health check workflow manually
gh workflow run validate-deployment.yml -f environment=dev

# Should complete in ~2 minutes
# Output should show clear PASS/FAIL
```

### Test 3: End-to-End

```bash
# Push a change that triggers terraform apply
# Wait for both workflows to complete
# Health check should show PASS before proceeding
```

---

## Questions?

See `/DEPLOYMENT_HEALTH_CHECK.md` in rag-research-tool for integration details.
