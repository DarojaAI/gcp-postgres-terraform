# Breaking Changes - VPC Infrastructure Refactor

**Release**: v1.27.0  
**Date**: 2026-04-26

## Summary

This release **requires vpc-infra module** and removes VPC creation fallback logic. This enforces the unified architecture and prevents configuration errors.

## What Changed

### ❌ No Longer Supported

1. **Standalone VPC creation**: Module no longer creates its own VPC network or subnets
2. **Cloud NAT management**: Cloud NAT is now managed by vpc-infra only
3. **VPC Access Connector creation**: Connector is created by vpc-infra (not this module)
4. Optional `vpc_name` and `subnet_name`: These are now **required**

### ✅ Now Required

```hcl
module "postgres" {
  source = "github.com/DarojaAI/gcp-postgres-terraform//terraform?ref=v1.27.0"

  # REQUIRED: Must be provided (created by vpc-infra)
  vpc_name    = module.vpc.vpc_name
  subnet_name = module.vpc.subnet_names[0]  # or your subnet name

  # ... other variables
}
```

### 🗑️ Removed Variables

- `subnet_cidr`: No longer used (subnet created by vpc-infra)
- `enable_cloud_nat`: Removed (Cloud NAT always created by vpc-infra)
- `vpc_connector_cidr`: Removed (connector created by vpc-infra)
- `vpc_connector_min_instances`: Removed (connector managed by vpc-infra)
- `vpc_connector_max_instances`: Removed (connector managed by vpc-infra)

### 🗑️ Removed Outputs

- `vpc_connector_name`: Use `module.vpc.vpc_connector_name` instead
- `vpc_connector_cidr`: Use `module.vpc.vpc_connector_cidr` (if exposed by vpc-infra)

## Migration Guide

### Before (Old Pattern)

```hcl
module "postgres" {
  source = "github.com/DarojaAI/gcp-postgres-terraform//terraform?ref=v1.26.0"
  
  project_id          = var.project_id
  instance_name       = "my-postgres"
  
  # Optional - created if empty
  vpc_name = ""  # Create new VPC
  subnet_cidr = "10.8.0.0/24"
  
  # VPC connector configured here
  vpc_connector_cidr = "10.8.1.0/28"
}
```

### After (New Pattern)

```hcl
# Step 1: Create VPC infrastructure
module "vpc" {
  source = "github.com/DarojaAI/vpc-infra//terraform?ref=v1.0.0"
  
  project_id  = var.project_id
  vpc_name    = "my-vpc"
  
  subnets = [
    {
      name = "postgres-subnet"
      cidr = "10.8.0.0/24"
    }
  ]
}

# Step 2: Reference VPC in PostgreSQL module
module "postgres" {
  source = "github.com/DarojaAI/gcp-postgres-terraform//terraform?ref=v1.27.0"
  
  project_id          = var.project_id
  instance_name       = "my-postgres"
  
  # REQUIRED: From vpc-infra
  vpc_name    = module.vpc.vpc_name
  subnet_name = module.vpc.subnet_names[0]
  
  # PostgreSQL config
  postgres_version = "15"
  postgres_db_name = "mydb"
}
```

## Why This Change

1. **Unified architecture**: VPC infrastructure now managed in one place (vpc-infra)
2. **Prevents bugs**: Can't accidentally reference non-existent VPC/connector
3. **Clearer intent**: Module explicitly depends on vpc-infra, not implicit
4. **Easier maintenance**: One source of truth for networking

## Dependencies

This version requires:
- `vpc-infra >= v1.0.0` (for VPC, subnets, Cloud NAT, VPC Access Connector)

## For Existing Projects

### If you created a VPC manually (not with vpc-infra):

You have two options:

**Option A: Create vpc-infra module (recommended)**
```bash
# Create vpc-infra repo locally
git clone https://github.com/DarojaAI/vpc-infra.git

# Deploy it once per GCP project
cd vpc-infra/terraform
terraform apply

# Then update your postgres module to reference it
```

**Option B: Stay on v1.26.0**
```hcl
module "postgres" {
  source = "github.com/DarojaAI/gcp-postgres-terraform//terraform?ref=v1.26.0"
  # Old pattern still works
}
```

## Support

- Questions? Check UNIFIED_INTEGRATION_GUIDE.md
- Issues? File GitHub issue with project name + terraform state snippet
- Migration help? See examples/ folder

## Rollback

If you need to revert to the old pattern:
```bash
git checkout v1.26.0
```

But note: v1.26.0 will NOT be maintained going forward. Plan migration to v1.27.0+.
