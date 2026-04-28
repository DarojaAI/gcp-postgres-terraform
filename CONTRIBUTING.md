# Contributing to gcp-postgres-terraform

See [DarojaAI/.github/CONTRIBUTING.md](https://github.com/DarojaAI/.github/blob/main/CONTRIBUTING.md) for organization-wide guidelines.

## This Repo: PostgreSQL Infrastructure

This repository manages PostgreSQL deployment on Google Cloud Platform using Terraform.

### Setup

```bash
# Install Terraform
terraform version  # Should be ≥1.5.0

# Install pre-commit hooks
pip install pre-commit
pre-commit install
```

### Before Committing

```bash
# Run pre-commit locally
pre-commit run --all-files

# Format Terraform
terraform fmt -recursive terraform/

# Validate configuration
terraform -chdir=terraform validate
```

### Testing Changes

```bash
# Plan (dry-run)
terraform -chdir=terraform plan

# Review output carefully before applying
```

### PR Process

1. **Create branch:** `git checkout -b fix/[description]`
2. **Make changes** in `terraform/` directory
3. **Run pre-commit:** `pre-commit run --all-files`
4. **Commit & push:** `git push origin [branch]`
5. **Create PR** — must include:
   - What changed (resource name + diff)
   - Why (bug fix, feature, upgrade)
   - Testing steps
   - Any data migration notes

### Versioning

Version is tracked in `package.json`:

```bash
# Bump version before release
npm version patch  # or minor/major

# GitHub Actions auto-tags and releases
```

### Important

- **Never commit terraform state files** (.tfstate)
- **Never commit credentials** in code (use secrets)
- **Always plan before apply** (review Checkov warnings)
- **Test in dev environment first**

---

For questions, see [GOVERNANCE.md](https://github.com/DarojaAI/.github/blob/main/GOVERNANCE.md)
