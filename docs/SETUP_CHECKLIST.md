# GCP Postgres Terraform — 45-Minute Setup Checklist

> Goal: Go from zero to deployed PostgreSQL in 45 minutes or less.

---

## Phase 1: Prerequisites (10 min)

- [ ] **GCP Project** with billing enabled
- [ ] **Terraform** >= 1.15.0 installed locally
- [ ] **gcloud** CLI authenticated (`gcloud auth application-default login`)
- [ ] **GitHub repo** created for your project
- [ ] **WIF configured** (see [CI-CD-SETUP.md](./CI-CD-SETUP.md))

## Phase 2: Copy Template (5 min)

```bash
# 1. Clone this repo for reference
git clone https://github.com/DarojaAI/gcp-postgres-terraform.git /tmp/gcp-postgres-ref

# 2. Copy the complete example to your project
cp -r /tmp/gcp-postgres-ref/examples/complete/* ./

# 3. Remove the example validators copy — use the module directly
rm -rf validators/
```

## Phase 3: Configure (10 min)

Edit `deploy/terraform/terraform.tfvars`:

```hcl
project_id           = "my-gcp-project-123"
repo_prefix          = "myapp"
environment          = "prod"
postgres_instance_name = "myapp-prod-pg"
postgres_db_password = "your-very-strong-password-here"
postgres_machine_type = "e2-medium"
github_repo          = "myorg/myapp"
```

**Critical**: Customize `repo_prefix` and `instance_name`. Never use defaults.

## Phase 4: Validate (5 min)

```bash
# Install validators
pip install git+https://github.com/DarojaAI/gcp-postgres-terraform.git#subdirectory=validators

# Run pre-flight checks
python -m validators.config
```

Fix any errors before proceeding.

## Phase 5: Deploy (15 min)

```bash
cd deploy/terraform

# Initialize
terraform init

# Plan and review
terraform plan -out=tfplan

# Apply
terraform apply tfplan
```

## Phase 6: Verify (5 min)

```bash
# Check instance is running
gcloud compute instances list --filter="name~myapp-prod-pg"

# Test connectivity (from Cloud Run or bastion)
psql -h <INTERNAL_IP> -U postgres -d postgres -c "SELECT version();"
```

---

## Common Pitfalls

| Issue | Cause | Fix |
|-------|-------|-----|
| `project_id` invalid | Using project *name* instead of ID | Use the ID from `gcloud projects list` |
| `repo_prefix` collision | Using default "rag-research" | Set a project-specific prefix |
| Password rejected | Too short or common | Use 12+ chars, mixed case, numbers |
| VPC connector fails | CIDR overlap with existing VPC | Pick a unique `/28` block |
| Terraform state lock | Previous run crashed | `terraform force-unlock <ID>` |

---

## Next Steps

1. Add your application resources to `deploy/terraform/main.tf`
2. Configure CI/CD with `.github/workflows/deploy.yml`
3. Set up monitoring alerts (see module outputs)
4. Document your schema in `deploy/terraform/schemas/`
