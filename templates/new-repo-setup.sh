#!/usr/bin/env bash
#
# new-repo-setup.sh — Bootstrap a new repo with gcp-postgres-terraform
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/DarojaAI/gcp-postgres-terraform/main/templates/new-repo-setup.sh | bash
#
# Or locally:
#   bash new-repo-setup.sh --project-id my-project --repo-prefix myapp --instance myapp-pg

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ID=""
REPO_PREFIX=""
INSTANCE_NAME=""
REGION="us-central1"
ZONE="us-central1-b"
MACHINE_TYPE="e2-medium"
ENVIRONMENT="prod"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Bootstrap a new repository with gcp-postgres-terraform.

Required:
  --project-id ID       GCP project ID
  --repo-prefix PREFIX  Resource naming prefix (e.g., myapp)
  --instance-name NAME  PostgreSQL instance name (e.g., myapp-prod-pg)

Optional:
  --region REGION       GCP region (default: us-central1)
  --zone ZONE           GCP zone (default: us-central1-b)
  --machine-type TYPE   VM machine type (default: e2-medium)
  --environment ENV     Environment name (default: prod)
  --help                Show this help

Example:
  $(basename "$0") --project-id my-gcp-123 --repo-prefix myapp --instance-name myapp-prod-pg
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --project-id) PROJECT_ID="$2"; shift 2 ;;
        --repo-prefix) REPO_PREFIX="$2"; shift 2 ;;
        --instance-name) INSTANCE_NAME="$2"; shift 2 ;;
        --region) REGION="$2"; shift 2 ;;
        --zone) ZONE="$2"; shift 2 ;;
        --machine-type) MACHINE_TYPE="$2"; shift 2 ;;
        --environment) ENVIRONMENT="$2"; shift 2 ;;
        --help) usage; exit 0 ;;
        *) echo "Unknown option: $1"; usage; exit 1 ;;
    esac
done

# Validate required args
if [[ -z "$PROJECT_ID" || -z "$REPO_PREFIX" || -z "$INSTANCE_NAME" ]]; then
    echo "❌ Missing required arguments"
    usage
    exit 1
fi

# Validate project ID format
if ! [[ "$PROJECT_ID" =~ ^[a-z][a-z0-9-]{4,28}[a-z0-9]$ ]]; then
    echo "❌ Invalid project_id format: $PROJECT_ID"
    echo "   Must be 6-30 chars, start with letter, lowercase letters/numbers/hyphens only"
    exit 1
fi

# Validate instance name
if ! [[ "$INSTANCE_NAME" =~ ^[a-z0-9][a-z0-9-]*[a-z0-9]$ ]]; then
    echo "❌ Invalid instance_name format: $INSTANCE_NAME"
    exit 1
fi

if [[ "$INSTANCE_NAME" =~ ^(postgres|default|main|master)$ ]]; then
    echo "❌ Instance name '$INSTANCE_NAME' is too generic and will cause collisions"
    exit 1
fi

echo "🚀 Bootstrapping repo with gcp-postgres-terraform..."
echo "   Project: $PROJECT_ID"
echo "   Prefix:  $REPO_PREFIX"
echo "   Instance: $INSTANCE_NAME"
echo ""

# Create directory structure
mkdir -p deploy/terraform/schemas
mkdir -p .github/workflows
mkdir -p scripts

echo "📁 Created directory structure"

# Copy example files
EXAMPLE_URL="https://raw.githubusercontent.com/DarojaAI/gcp-postgres-terraform/main/examples/complete"

# Download terraform files
curl -sSL "$EXAMPLE_URL/deploy/terraform/main.tf" > deploy/terraform/main.tf
curl -sSL "$EXAMPLE_URL/deploy/terraform/variables.tf" > deploy/terraform/variables.tf
curl -sSL "$EXAMPLE_URL/deploy/terraform/outputs.tf" > deploy/terraform/outputs.tf

# Download workflow
curl -sSL "$EXAMPLE_URL/.github/workflows/deploy.yml" > .github/workflows/deploy.yml

echo "📥 Downloaded template files"

# Generate terraform.tfvars
cat > deploy/terraform/terraform.tfvars <<EOF
project_id             = "$PROJECT_ID"
repo_prefix            = "$REPO_PREFIX"
environment            = "$ENVIRONMENT"
postgres_instance_name = "$INSTANCE_NAME"
postgres_version       = "15"
postgres_db_name       = "postgres"
postgres_db_user       = "postgres"
postgres_db_password   = "CHANGE_ME_IN_SECRET_MANAGER"
postgres_machine_type  = "$MACHINE_TYPE"
pgvector_enabled       = true
github_repo            = "$(git remote get-url origin 2>/dev/null | sed 's/.*github.com\///;s/\.git$//' || echo 'owner/repo')"
region                 = "$REGION"
zone                   = "$ZONE"
subnet_cidr            = "10.8.0.0/24"
connector_cidr         = "10.8.1.0/28"
disk_size_gb           = 20
backup_enabled         = true
EOF

echo "⚙️  Generated terraform.tfvars"

# Create placeholder schema
cat > deploy/terraform/schemas/init.sql <<'EOF'
-- Initial schema for PostgreSQL
-- Add your tables, indexes, and extensions here

-- Example: Enable pgvector (if pgvector_enabled = true)
-- CREATE EXTENSION IF NOT EXISTS vector;

-- Example: Create a table
-- CREATE TABLE IF NOT EXISTS example (
--     id SERIAL PRIMARY KEY,
--     name TEXT NOT NULL,
--     embedding vector(1536),
--     created_at TIMESTAMP DEFAULT NOW()
-- );
EOF

echo "🗄️  Created placeholder schema"

# Create backend.tf
cat > deploy/terraform/backend.tf <<EOF
terraform {
  backend "gcs" {
    bucket = "${PROJECT_ID}-terraform-state"
    prefix = "postgres"
  }
}
EOF

echo "☁️  Created backend.tf"

# Create README for deploy folder
cat > deploy/README.md <<EOF
# Infrastructure Deployment

## Quick Start

1. **Set password in Secret Manager** (do NOT commit to git):
   \`\`\`bash
   gcloud secrets versions add postgres-db-password --data-file=<(echo -n 'your-strong-password')
   \`\`\`

2. **Validate configuration**:
   \`\`\`bash
   pip install git+https://github.com/DarojaAI/gcp-postgres-terraform.git#subdirectory=validators
   python -m validators.config
   \`\`\`

3. **Deploy**:
   \`\`\`bash
   cd terraform
   terraform init
   terraform plan -out=tfplan
   terraform apply tfplan
   \`\`\`

## Files

- \`main.tf\` — Module call + your app resources
- \`variables.tf\` — Input variables
- \`outputs.tf\` — Useful outputs
- \`terraform.tfvars\` — Your configuration (gitignored)
- \`schemas/init.sql\` — Schema loaded at provisioning
- \`backend.tf\` — GCS remote state

## CI/CD

GitHub Actions workflow in \`.github/workflows/deploy.yml\` runs on push to main.
EOF

echo "📝 Created README"

# Add to .gitignore if not present
if [[ -f .gitignore ]]; then
    if ! grep -q "terraform.tfvars" .gitignore; then
        echo "terraform.tfvars" >> .gitignore
        echo "*.tfstate*" >> .gitignore
        echo ".terraform/" >> .gitignore
        echo "🚫 Updated .gitignore"
    fi
else
    cat > .gitignore <<EOF
terraform.tfvars
*.tfstate*
.terraform/
.terraform.lock.hcl
EOF
    echo "🚫 Created .gitignore"
fi

echo ""
echo "✅ Bootstrap complete!"
echo ""
echo "Next steps:"
echo "  1. Review deploy/terraform/terraform.tfvars"
echo "  2. Set your PostgreSQL password in Secret Manager"
echo "  3. Run: python -m validators.config (after installing validators)"
echo "  4. Commit and push: git add deploy/ .github/ && git commit -m 'feat: add postgres infrastructure'"
echo ""
