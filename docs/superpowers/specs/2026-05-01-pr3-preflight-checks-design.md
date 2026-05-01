# PR3 — Preflight Checks Design

**Date:** 2026-05-01
**PR:** ROBUSTNESS-PLAN.md → PR3 (Preflight Checks)
**Status:** Approved by user

## Overview

Add two preflight validations to prevent deployment failures:

1. **NAT preflight** — validate Cloud NAT exists before creating a VM without external IP
2. **GHA IP allowlist gating** — make GitHub Actions IP fetching optional (default off)

Both checks validate at **plan time** via `lifecycle.precondition`, catching misconfigurations before any resources are created.

---

## Component 1: NAT Preflight Check

### Problem

When `enable_cloud_nat = true` and `assign_external_ip = false`, the VM requires Cloud NAT for outbound internet access (apt-get, package installs). If NAT is missing, the VM boots but hangs at network operations, wasting 10+ minutes before failure.

### Solution

Add a data source to look up the NAT router, then validate at plan time that NAT exists when needed.

### Implementation

**New variable:**

```hcl
variable "nat_project_id" {
  description = "Project containing the Cloud NAT router (defaults to var.project_id)"
  type        = string
  default     = ""
}
```

**Data source** (new block in `terraform/postgres_module.tf`):

```hcl
data "google_compute_router_nat" "main" {
  # Use var.nat_project_id if set, otherwise fall back to var.project_id
  project = var.nat_project_id != "" ? var.nat_project_id : var.project_id
  region  = var.region
  name    = "nat-${var.vpc_name}"
}
```

**Lifecycle precondition** (add to `google_compute_instance.postgres`):

```hcl
lifecycle {
  precondition {
    condition     = var.assign_external_ip || !var.enable_cloud_nat || data.google_compute_router_nat.main.id != ""
    error_message = "Cloud NAT is required when assign_external_ip=false and enable_cloud_nat=true. Ensure NAT is configured in the VPC (set var.nat_project_id if NAT lives in a different project)."
  }
}
```

**Logic:**
- If `assign_external_ip = true` → OK (VM has public IP, no NAT needed)
- If `enable_cloud_nat = false` → OK (user explicitly disabled NAT)
- Otherwise → NAT must exist (lookup succeeds)

### NAT Naming Assumption

The lookup assumes NAT is named `nat-${var.vpc_name}`, matching the typical vpc-infra module convention. This is a reasonable assumption — if a consumer uses different naming, they can set up the NAT in the expected project with the expected name.

---

## Component 2: GHA IP Allowlist Gating

### Problem

The `data "http" "github_actions_ips"` block (lines 17-32 in `postgres_module.tf`) fetches GitHub's IP ranges on every plan. This adds:
- Non-deterministic plan output (IPs change over time)
- Broad firewall surface (thousands of IPs)
- No value for this repo (no workflow connects GHA → Postgres)

### Solution

Make the GitHub IP fetch opt-in via a boolean flag.

### Implementation

**New variable:**

```hcl
variable "allow_github_actions_ingress" {
  description = "Allow GitHub Actions runners to connect to PostgreSQL. When true, fetches GitHub IP ranges and adds them to the firewall rule. Default false."
  type        = bool
  default     = false
}
```

**Conditionally include HTTP data source:**

```hcl
data "http" "github_actions_ips" {
  count = var.allow_github_actions_ingress ? 1 : 0
  url = "https://api.github.com/meta"
  request_headers = {
    Accept = "application/vnd.github+json"
  }
}

locals {
  github_actions_ipv4 = var.allow_github_actions_ingress ? [
    for cidr in jsondecode(data.http.github_actions_ips[0].response_body).actions :
    length(regexall(":", cidr)) > 0 ? "" : format("%s.0.0/16", join(".", slice(split(".", cidr), 0, 2)))
  ] : []
  github_actions_cidrs = distinct(local.github_actions_ipv4)
}
```

**Firewall rule source_ranges (modify existing):**

```hcl
source_ranges = compact(distinct(concat(
  [var.subnet_cidr],
  var.vpc_connector_cidr != "" ? [var.vpc_connector_cidr] : [],
  local.github_actions_cidrs,  # Empty when allow_github_actions_ingress = false
  var.allow_postgres_from_cidrs
)))
```

### Behavior

| `allow_github_actions_ingress` | HTTP data source | Firewall includes GHA IPs |
|---|---|---|
| `false` (default) | Not created | No |
| `true` | Created | Yes |

---

## Files Modified

| File | Change |
|---|---|
| `terraform/variables.tf` | Add `nat_project_id`, `allow_github_actions_ingress` |
| `terraform/postgres_module.tf` | Add `data "google_compute_router_nat"`, add lifecycle precondition, modify firewall logic |

---

## Backward Compatibility

- **NAT preflight:** New check only applies when `enable_cloud_nat = true` and `assign_external_ip = false`. Existing deployments with public IPs or NAT disabled are unaffected.
- **GHA IP gating:** Default is `false`, which means existing deployments lose GHA ingress on first apply. This is **breaking** — users relying on GHA → Postgres must explicitly set `allow_github_actions_ingress = true`.

The ROBUSTNESS-PLAN.md documents this as a breaking change that ships in the bundled 2.0.0 release.

---

## Testing

1. **Default case:** `terraform plan` with defaults — verify no HTTP data source, no NAT lookup
2. **GHA enabled:** Set `allow_github_actions_ingress = true` — verify data source created, IPs in plan
3. **NAT missing:** Set `enable_cloud_nat = true`, `assign_external_ip = false`, no NAT in project — verify plan fails with error message
4. **NAT present:** Create NAT in project — verify plan succeeds
5. **NAT in different project:** Set `nat_project_id` to different project — verify lookup succeeds

---

## Notes

- NAT name assumption (`nat-${var.vpc_name}`) matches vpc-infra module. Document in `docs/CI-CD-SETUP.md` if consumers need to follow this naming.
- GHA IP fetch uses existing logic (aggregates to /16 blocks, filters IPv6).
- The `count` pattern is already used in this module (`google_compute_firewall.allow_ssh` at line 98), so it's a familiar pattern.