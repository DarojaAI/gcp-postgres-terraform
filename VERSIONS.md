# Version Tracking: gcp-postgres-terraform

## Current Version: 2.0.0

### Module Details
- **Name:** gcp-postgres-terraform
- **Type:** PostgreSQL Database Deployment Module
- **Status:** Production Ready
- **Repository:** https://github.com/DarojaAI/gcp-postgres-terraform

### Dependencies
| Dependency | Version | Required | Status |
|------------|---------|----------|--------|
| Terraform | >= 1.6 | Yes | ✅ Compatible |
| Google Provider | ~> 7.0 | Yes | ✅ Current |
| gcp-vpc-egress-terraform | >= 1.0.0 | Optional | ℹ️ For VPC |
| Cloud SQL (optional) | - | Optional | ℹ️ Managed database |

### Terraform Requirements
```hcl
terraform {
  required_version = ">= 1.6"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
}
```

### Release History
| Version | Date | Changes | Status |
|---------|------|---------|--------|
| 2.0.0 | 2026-04-28 | Updated to google 7.0, aligned with ecosystem | ✅ Released |
| 1.x.x | Earlier | Previous versions | 🚫 Deprecated |

### Integration Guide

**Used By:**
- rag-research-tool (via module reference)
- Any GCP project needing PostgreSQL VMs

**Compatible With:**
- gcp-vpc-egress-terraform (for networking)
- gcp-dbt-terraform (for data transformations)

**Breaking Changes in 2.0.0:**
- Google provider updated to ~> 7.0
- Terraform version now >= 1.6
- Migration guide: See CHANGELOG.md

### Notes
- Version 2.0.0 uses google provider 7.0
- Compatible with all modern GCP services
- Startup script enhanced with health checks in deployment
