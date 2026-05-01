# Robustness Plan — gcp-postgres-terraform

This document captures the architectural improvements identified during the
deployment-robustness audit. The goal: make the module succeed first-time,
catch failures at plan time rather than mid-deploy, and verify end-to-end
connectivity rather than VM-local liveness.

## Background — resolved issues

All 10 issues have been resolved as of v2.0.0:

| # | Problem | Fix |
|---|---|---|
| 1 | Validator looks up wrong VM name | Now reads from `terraform output -raw instance_name` |
| 2 | Validator only checks VM-local state | Added TCP connectivity test, extension verification, READY sentinel check |
| 3 | Data disk mounted but unused | Pre-seeded `/etc/postgresql-common/createcluster.conf` with data_directory |
| 4 | No preflight check for Cloud NAT | Added NAT lookup with lifecycle.precondition |
| 5 | Init script non-idempotent | Added step sentinels + apt-get retry with exponential backoff |
| 6 | pgvector extension name wrong | Changed to `CREATE EXTENSION IF NOT EXISTS vector` |
| 7 | No completion sentinel | Writes `/var/lib/postgres-setup/READY` on success |
| 8 | GHA IP non-determinism | Added `var.allow_github_actions_ingress` (default false) |
| 9 | Production-hostile defaults | Changed to pd-balanced, force_destroy=false, log_statement off |
| 10 | Secret version growth | Removed redundant null_resource.sync_secrets |

## PR breakdown

PRs are bundled by deployment shape (do they change behavior, do they break
existing instances) rather than by file. This makes Release Please version
bumps clean and migration guides single-PR-scoped.

### PR1 — Correctness bugs (`fix:` → patch bump)

**Independent. No deployment shape change.**

- Fix `.github/workflows/validate-deployment.yml:56` to read `instance_name`
  from `terraform output -raw instance_name` rather than hardcoding
  `postgres-vm-${ENV}`.
- Fix `terraform/scripts/postgres_init.sh:257` — change `CREATE EXTENSION IF
  NOT EXISTS pgvector` to `CREATE EXTENSION IF NOT EXISTS vector` (the
  extension shipped by `postgresql-${VERSION}-pgvector` is named `vector`).
- Fix `terraform/scripts/postgres_init.sh:388` — same rename in the health
  check grep.

**Test:** redeploy to dev, confirm `\dx` shows `vector` and the validator
finds the VM.

**Release:** `1.29.0` → `1.29.1`.

---

### PR7 — Stop unbounded secret version growth (`fix:` → patch bump)

**Independent. No behavior change to consumers.**

`null_resource.sync_secrets` (`terraform/postgres_module.tf:536`) duplicates
what `google_secret_manager_secret_version` resources at lines 260, 274, 288,
302 already do. Each apply creates four new secret versions even when nothing
changed — eventually hits Secret Manager version quotas.

- Delete `null_resource.sync_secrets` writes; native resources cover the
  recreation case via implicit dependencies on
  `google_compute_address.postgres_ip.address`.
- Optionally retain a read-only verification step (no writes) if anyone
  relies on the validation logging.
- Bonus: removes the `gcloud` PATH requirement for local `terraform apply`.

**Test:** `terraform apply` twice on a no-op state, confirm only one new
version per secret was created (or zero on the second apply).

**Release:** `1.29.x` → next patch.

---

### PR2 — Deeper validator (`feat:` → minor bump)

**Depends on PR1.** PR1 must merge first or the validator still can't find
the VM.

Augment `.github/workflows/validate-deployment.yml`:

1. Read `internal_ip`, `db_name`, `db_user` from `terraform output`.
2. Fetch the application user's password from Secret Manager:
   `gcloud secrets versions access latest --secret=...`.
3. `apt-get install -y postgresql-client` on the runner.
4. **TCP connection test from the runner** using application user — proves
   firewall + `listen_addresses` + `pg_hba.conf` + password all work
   end-to-end (not just `sudo -u postgres psql` over a Unix socket).
5. **Extension verification:**
   `SELECT extname FROM pg_extension WHERE extname='vector';` — fail if
   missing.
6. **Library load verification:**
   `SELECT count(*) FROM pg_settings WHERE name='shared_preload_libraries' AND setting LIKE '%vector%';`
   — fail if zero. Catches install-but-not-loaded regressions.

**Prerequisite:** WIF service account needs `roles/secretmanager.secretAccessor`
on the password secret. Document in `docs/CI-CD-SETUP.md`. Add a clear
failure message in the workflow if the perm is missing
(`gcloud secrets versions access` returns 403).

**Release:** `1.29.x` → `1.30.0`.

---

### PR4 — Idempotent + retryable init script (`feat:` → minor bump)

**Depends on PR2.** PR2's `READY` sentinel check assumes the init script
writes one.

Refactor `terraform/scripts/postgres_init.sh`:

- Per-step sentinel files in `/var/lib/postgres-setup/`. Each step:
  ```bash
  [[ -f /var/lib/postgres-setup/step-N-done ]] && { echo "step N: skipping (already done)"; continue; }
  # ... do work ...
  touch /var/lib/postgres-setup/step-N-done
  ```
- Wrap `apt-get update` in 3-retry loop with exponential backoff
  (10s, 30s, 90s).
- At very end, write `/var/lib/postgres-setup/READY`.
- Update PR2's validator to check for the `READY` file before declaring
  success — distinguishes "init completed" from "Postgres happens to be up
  but init exited mid-run."

**Test:** SSH in, `rm /var/lib/postgres-setup/step-7-done`, re-run script
manually, confirm only steps 7+ rerun.

**Release:** `1.30.x` → `1.31.0`.

---

### Bundled major (`feat!:` → 2.0.0)

PR3, PR5, and PR6 all break existing deployments. Ship as one bundled PR
under one major version bump with one migration guide. Asking users to
migrate three times in three releases is hostile.

#### PR3 component — Preflight checks

1. **NAT preflight.** Add `data "google_compute_router_nat"` lookup against
   the subnet's region. Wrap the VM resource in a `lifecycle.precondition`
   that fails plan if NAT is not found AND `assign_external_ip = false` AND
   `enable_cloud_nat = true`. Error message points consumers at their
   `vpc-infra` module configuration. Skip the check if `assign_external_ip = true`.

2. **GHA IP allowlist gating.** Gate `data "http" "github_actions_ips"`
   behind new `var.allow_github_actions_ingress` (default `false`). When
   false, skip the data fetch and contribute empty list to the firewall
   `source_ranges`. Confirmed: no workflow in this repo uses GHA → Postgres,
   but downstream dbt consumers may rely on it (per comment at
   `terraform/postgres_module.tf:16`). Document in `docs/CI-CD-SETUP.md`
   that consumers running CI dbt validation set this to `true`.

   Why this is breaking: existing deployments lose GHA ingress on apply
   unless they opt back in.

#### PR5 component — Force data disk usage

User chose option (c): release as breaking, document mandatory backup +
recreate. **Existing deployments lose data on apply.**

In `terraform/scripts/postgres_init.sh`, before `apt-get install
postgresql-$VERSION` runs the cluster init, configure the apt postinst to
use `/mnt/postgres-data/pg_data` as `data_directory`. Two implementation
options:

- **Option A:** Pre-seed `/etc/postgresql-common/createcluster.conf` to set
  `data_directory = '/mnt/postgres-data/pg_data'` before install.
- **Option B:** After install, `pg_dropcluster $VERSION main && pg_createcluster $VERSION main -d /mnt/postgres-data/pg_data`.

Option A is preferable — runs once, no race window where the cluster lives
in the wrong place. Verify with
`sudo -u postgres psql -c "SHOW data_directory"` returning the mount path;
add this assertion to the init script's health checks AND to the PR2
validator (catches regressions).

#### PR6 component — Production defaults

**Status: MERGED (v2.0.0)**

1. `disk_type` default: `pd-standard` → `pd-balanced`. Existing deployments
   with explicit `disk_type` unaffected; deployments using the default get a
   disk-type change which **forces VM replacement**.
2. `force_destroy = true` on backup bucket → introduce
   `var.backup_bucket_force_destroy` (default `false`). To preserve current
   behavior, consumers set this to `true`.
3. `log_statement = 'all'` → introduce `var.log_all_statements` (default
   `false`). Only emit the postgresql.conf line when true. Stops logging
   sensitive INSERT data in prod by default.

#### Migration guide (lives in CHANGELOG / release notes)

```
1. Take pg_dump backups:
   gcloud compute ssh pg-<instance> --zone=<zone> -- \
     "sudo -u postgres pg_dump <dbname>" > backup.sql

2. If you were relying on previous defaults, set these vars to preserve behavior:
   - allow_github_actions_ingress = true   # if your CI uses dbt-to-Postgres
   - backup_bucket_force_destroy = true    # if you want destroy to nuke backups
   - log_all_statements = true             # if you actually want all-statement logs (dev only)
   - disk_type = "pd-standard"             # if you want to keep HDD

3. terraform apply (will recreate VM, data lost)

4. Restore: psql ... < backup.sql
```

**Release:** `1.31.x` → `2.0.0`. Use one `feat!:` commit with `BREAKING
CHANGE:` footer enumerating all three components.

---

### Test gate (per PR)

Before merging any of the above, run a full lifecycle test against a
**separate dev GCP project** (NOT the prod project — `terraform destroy`
misclicks are unrecoverable).

```
1. checkout PR branch
2. terraform init && terraform apply -var-file=dev.tfvars
3. trigger validate-deployment.yml workflow_dispatch
4. verify all checks green
5. (optional) gcloud compute ssh pg-<instance> -- "sudo -u postgres psql -c '\dx'"
6. terraform destroy
```

Capture output in PR description. Turns "tests pass" into "we proved it
works."

---

### Release sequence doc (after PR6 lands)

Add a `docs/RELEASE-PLAN.md` or top-of-CHANGELOG entry with the version
sequence for transparency to downstream consumers:

| Order | PR | Status | Version |
|---|---|---|---|
| 1 | PR1 | Done (merged) | 1.29.1 |
| 2 | PR7 | Done (merged) | 1.29.2 |
| 3 | PR2 | Done (merged) | 1.30.0 |
| 4 | PR4 | Done (merged) | 1.30.0 |
| 5 | PR6 | Done (merged) | 2.0.0 |
| 6 | PR3 (Preflight checks) | Done (merged) | 2.0.0 |
| 7 | PR5 (Data disk fix) | Done (merged) | 2.0.0 |

**Note:** All 7 PRs are now complete. PR2+PR4+PR3+PR5 were merged together in PR #17 (v1.30.0 then 2.0.0). The data disk fix uses Option A: pre-seeded `/etc/postgresql-common/createcluster.conf` with `data_directory = '/mnt/postgres-data/pg_data'`.

## Decisions captured

- **Scope:** all 10 items, broken into 7 PRs by deployment shape.
- **Data disk fix:** ship as breaking change (option c), not opt-in flag.
- **GHA IP allowlist:** confirmed unused by this repo's workflows, but kept
  as an opt-in feature for downstream dbt consumers — gated to off by
  default rather than removed.
- **Test environment:** user has a prod project; plan calls for a separate
  dev project for apply/destroy cycles. **Open question:** does this dev
  project exist, or does it need to be stood up?
- **Bundled major release:** PR3 and PR6 shipped in PR #17 as 2.0.0.
  PR5 (data disk fix) remains pending.

## Open questions

1. Does a dev GCP project exist for E2E testing, or does one need to be
   provisioned?
2. **For PR5 data disk fix: prefer Option A (pre-seed
   `createcluster.conf`) or Option B (drop + recreate cluster)?**
3. ~~PR2 needs WIF SA to have `secretmanager.secretAccessor` — is that
   already granted in the consuming repo, or does PR2 also need to update
   bootstrap docs?~~ (Implemented in PR2)
