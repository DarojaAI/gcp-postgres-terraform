# PR3 — Preflight Checks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement NAT preflight validation and GHA IP allowlist gating as defined in spec `docs/superpowers/specs/2026-05-01-pr3-preflight-checks-design.md`

**Architecture:** Two independent components: (1) NAT lookup with lifecycle precondition on VM, (2) conditional HTTP data source and firewall rule. Both add plan-time validation to catch misconfigurations early.

**Tech Stack:** Terraform, GCP Compute Router NAT, GCP Firewall Rules

---

## File Structure

| File | Change |
|---|---|
| `terraform/variables.tf` | Add `nat_project_id`, `allow_github_actions_ingress` |
| `terraform/postgres_module.tf` | Add NAT data source, add lifecycle precondition, modify firewall logic |

---

## Task 1: Add NAT Project Variable

**Files:**
- Modify: `terraform/variables.tf`

- [ ] **Step 1: Add nat_project_id variable**

Add at end of variables.tf (after line 362):

```hcl
variable "nat_project_id" {
  description = "Project containing the Cloud NAT router (defaults to var.project_id)"
  type        = string
  default     = ""
}
```

- [ ] **Step 2: Validate syntax**

Run: `terraform -chdir=terraform validate`
Expected: Success (no changes to apply)

- [ ] **Step 3: Commit**

Run: `git add terraform/variables.tf && git commit -m "feat: add nat_project_id variable for NAT preflight check"`

---

## Task 2: Add GHA Ingress Variable

**Files:**
- Modify: `terraform/variables.tf`

- [ ] **Step 1: Add allow_github_actions_ingress variable**

Add after `nat_project_id` variable (around line 365):

```hcl
variable "allow_github_actions_ingress" {
  description = "Allow GitHub Actions runners to connect to PostgreSQL. When true, fetches GitHub IP ranges and adds them to the firewall rule. Default false."
  type        = bool
  default     = false
}
```

- [ ] **Step 2: Validate syntax**

Run: `terraform -chdir=terraform validate`
Expected: Success

- [ ] **Step 3: Commit**

Run: `git add terraform/variables.tf && git commit -m "feat: add allow_github_actions_ingress for optional GHA IP allowlist"`

---

## Task 3: Add NAT Data Source

**Files:**
- Modify: `terraform/postgres_module.tf`

- [ ] **Step 1: Add google_compute_router_nat data source**

Add after line 32 (after the locals block, before "# Enable required GCP APIs"):

```hcl
# NAT router lookup for preflight validation
data "google_compute_router_nat" "main" {
  # Use var.nat_project_id if set, otherwise fall back to var.project_id
  project = var.nat_project_id != "" ? var.nat_project_id : var.project_id
  region  = var.region
  name    = "nat-${var.vpc_name}"
}
```

- [ ] **Step 2: Validate syntax**

Run: `terraform -chdir=terraform init -backend=false && terraform -chdir=terraform validate`
Expected: Success

Note: The data source will fail if NAT doesn't exist, but validate just checks syntax. The actual lookup happens at plan time.

- [ ] **Step 3: Commit**

Run: `git add terraform/postgres_module.tf && git commit -m "feat: add NAT router data source for preflight check"`

---

## Task 4: Add Lifecycle Precondition to VM

**Files:**
- Modify: `terraform/postgres_module.tf:317-399` (google_compute_instance.postgres)

- [ ] **Step 1: Add lifecycle precondition to VM**

Find the `google_compute_instance.postgres` resource (starts at line 317). Add this block inside the resource, after `can_ip_forward = true` and before `tags = ["postgres-server"]`:

```hcl
  lifecycle {
    precondition {
      condition     = var.assign_external_ip || !var.enable_cloud_nat || data.google_compute_router_nat.main.id != ""
      error_message = "Cloud NAT is required when assign_external_ip=false and enable_cloud_nat=true. Ensure NAT is configured in the VPC (set var.nat_project_id if NAT lives in a different project)."
    }
  }
```

- [ ] **Step 2: Validate syntax**

Run: `terraform -chdir=terraform validate`
Expected: Success

- [ ] **Step 3: Commit**

Run: `git add terraform/postgres_module.tf && git commit -m "feat: add NAT preflight validation to VM resource"`

---

## Task 5: Make GHA IP Data Source Conditional

**Files:**
- Modify: `terraform/postgres_module.tf:17-32`

- [ ] **Step 1: Modify HTTP data source to be conditional**

Replace lines 17-32 (the `data "http" "github_actions_ips"` and `locals` block) with:

```hcl
# Fetch GitHub Actions runner IP ranges for firewall allowlisting
# Only when allow_github_actions_ingress is enabled
data "http" "github_actions_ips" {
  count = var.allow_github_actions_ingress ? 1 : 0
  url = "https://api.github.com/meta"
  request_headers = {
    Accept = "application/vnd.github+json"
  }
}

# Extract and filter IPv4-only CIDRs from GitHub Actions IPs
# IPv4 CIDRs look like "13.64.0.0/11" - we aggregate to /16 blocks
# IPv6 addresses (containing ':') are filtered out as GCP firewall doesn't accept them
locals {
  github_actions_ipv4 = var.allow_github_actions_ingress ? [
    for cidr in jsondecode(data.http.github_actions_ips[0].response_body).actions :
    length(regexall(":", cidr)) > 0 ? "" : format("%s.0.0/16", join(".", slice(split(".", cidr), 0, 2)))
  ] : []
  github_actions_cidrs = distinct(local.github_actions_ipv4)
}
```

- [ ] **Step 2: Validate syntax**

Run: `terraform -chdir=terraform init -backend=false && terraform -chdir=terraform validate`
Expected: Success

- [ ] **Step 3: Commit**

Run: `git add terraform/postgres_module.tf && git commit -m "feat: make GHA IP fetch conditional on allow_github_actions_ingress"`

---

## Task 6: Modify Firewall Rule Source Ranges

**Files:**
- Modify: `terraform/postgres_module.tf:71-94` (google_compute_firewall.allow_postgres)

- [ ] **Step 1: Update source_ranges in firewall rule**

Replace lines 87-92 (the source_ranges argument) with:

```hcl
  source_ranges = compact(distinct(concat(
    [var.subnet_cidr],
    var.vpc_connector_cidr != "" ? [var.vpc_connector_cidr] : [],
    local.github_actions_cidrs,
    var.allow_postgres_from_cidrs
  )))
```

Note: `local.github_actions_cidrs` is now empty when `allow_github_actions_ingress = false`, so it won't add any IPs.

- [ ] **Step 2: Validate syntax**

Run: `terraform -chdir=terraform validate`
Expected: Success

- [ ] **Step 3: Verify default behavior (no GHA IPs)**

Run: `terraform -chdir=terraform plan -out=tfplan -var-file=dev.tfvars 2>&1 | head -50`
Expected: Plan runs without fetching GitHub IPs (no HTTP request to api.github.com)

- [ ] **Step 4: Commit**

Run: `git add terraform/postgres_module.tf && git commit -m "feat: update firewall rule to use conditional GHA CIDRs"`

---

## Task 7: End-to-End Validation

**Files:**
- No changes — testing only

- [ ] **Step 1: Run terraform fmt**

Run: `terraform -chdir=terraform fmt -check -diff`
Expected: Any needed formatting fixes shown (rerun with `-write` to apply)

- [ ] **Step 2: Run full validate**

Run: `terraform -chdir=terraform init -backend=false && terraform -chdir=terraform validate`
Expected: Success

- [ ] **Step 3: Test NAT preflight failure scenario**

Run: Create a test scenario where enable_cloud_nat=true, assign_external_ip=false, and no NAT exists. Verify plan fails with the error message.

- [ ] **Step 4: Commit final**

Run: `git commit --amend --no-edit` to squash all changes OR create a single commit for the feature:

```bash
git add -A && git commit -m "feat: add preflight checks for NAT validation and GHA IP gating"
```

---

## Spec Coverage Check

| Spec Requirement | Task |
|---|---|
| Add `nat_project_id` variable | Task 1 |
| Add `allow_github_actions_ingress` variable | Task 2 |
| Add `data "google_compute_router_nat"` lookup | Task 3 |
| Add lifecycle precondition to VM | Task 4 |
| Make HTTP data source conditional | Task 5 |
| Modify firewall source_ranges | Task 6 |
| Testing and validation | Task 7 |

All requirements covered.

---

**Plan complete and saved to `docs/superpowers/plans/2026-05-01-pr3-preflight-checks-plan.md`. Two execution options:**

1. **Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

2. **Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

Which approach?