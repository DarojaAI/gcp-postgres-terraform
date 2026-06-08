"""
GCP Postgres Terraform Module — Input Validators

Validates configuration BEFORE terraform apply to catch misconfigurations
early. Use in CI/CD pre-flight checks or local development.

Usage:
    from validators.config import PostgresConfig, validate_module_inputs
    config = PostgresConfig.from_env()
    errors = validate_module_inputs(config)
    if errors:
        raise ValueError(f"Configuration errors: {errors}")
"""

import os
import re
from dataclasses import dataclass, field
from typing import List, Optional, Set


# GCP project ID pattern: lowercase letters, numbers, hyphens
PROJECT_ID_PATTERN = re.compile(r"^[a-z][a-z0-9-]{4,28}[a-z0-9]$")

# Valid GCP machine types for PostgreSQL workloads
VALID_MACHINE_TYPES: Set[str] = {
    "e2-micro", "e2-small", "e2-medium", "e2-standard-2",
    "e2-standard-4", "e2-standard-8", "n2-standard-2",
    "n2-standard-4", "n2-standard-8",
}

# Valid PostgreSQL versions
VALID_POSTGRES_VERSIONS: Set[str] = {"14", "15", "16"}

# Valid GCP regions (common ones — expand as needed)
VALID_REGIONS: Set[str] = {
    "us-central1", "us-east1", "us-east4", "us-west1", "us-west2",
    "europe-west1", "europe-west2", "europe-west3",
    "asia-east1", "asia-northeast1", "asia-southeast1",
}

# Forbidden instance names that cause collisions
FORBIDDEN_NAMES: Set[str] = {"postgres", "default", "main", "master", "primary"}


@dataclass
class PostgresConfig:
    """Validated configuration for gcp-postgres-terraform module."""

    project_id: str
    instance_name: str
    repo_prefix: str = "my-project"
    environment: str = "prod"
    region: str = "us-central1"
    zone: str = "us-central1-b"
    postgres_version: str = "15"
    postgres_db_name: str = "postgres"
    postgres_db_user: str = "postgres"
    postgres_db_password: Optional[str] = None
    machine_type: str = "e2-medium"
    pgvector_enabled: bool = True
    github_actions_enabled: bool = False
    github_repo: Optional[str] = None
    vpc_name: Optional[str] = None
    subnet_cidr: str = "10.8.0.0/24"
    connector_cidr: str = "10.8.1.0/28"
    disk_size_gb: int = 20
    backup_enabled: bool = True
    init_sql: Optional[str] = None

    # Internal tracking
    _errors: List[str] = field(default_factory=list, repr=False)

    @classmethod
    def from_env(cls) -> "PostgresConfig":
        """Load configuration from environment variables."""
        return cls(
            project_id=os.getenv("GCP_PROJECT_ID", ""),
            instance_name=os.getenv("POSTGRES_INSTANCE_NAME", ""),
            repo_prefix=os.getenv("REPO_PREFIX", "my-project"),
            environment=os.getenv("ENVIRONMENT", "prod"),
            region=os.getenv("GCP_REGION", "us-central1"),
            zone=os.getenv("GCP_ZONE", "us-central1-b"),
            postgres_version=os.getenv("POSTGRES_VERSION", "15"),
            postgres_db_name=os.getenv("POSTGRES_DB_NAME", "postgres"),
            postgres_db_user=os.getenv("POSTGRES_DB_USER", "postgres"),
            postgres_db_password=os.getenv("POSTGRES_DB_PASSWORD"),
            machine_type=os.getenv("POSTGRES_MACHINE_TYPE", "e2-medium"),
            pgvector_enabled=os.getenv("PGVECTOR_ENABLED", "true").lower() == "true",
            github_actions_enabled=os.getenv("GITHUB_ACTIONS_ENABLED", "false").lower() == "true",
            github_repo=os.getenv("GITHUB_REPO"),
            vpc_name=os.getenv("VPC_NAME"),
            subnet_cidr=os.getenv("SUBNET_CIDR", "10.8.0.0/24"),
            connector_cidr=os.getenv("CONNECTOR_CIDR", "10.8.1.0/28"),
            disk_size_gb=int(os.getenv("DISK_SIZE_GB", "20")),
            backup_enabled=os.getenv("BACKUP_ENABLED", "true").lower() == "true",
            init_sql=os.getenv("INIT_SQL_PATH"),
        )

    def validate(self) -> List[str]:
        """Run all validations and return list of error messages."""
        errors: List[str] = []

        # Project ID
        if not self.project_id:
            errors.append("project_id is required")
        elif not PROJECT_ID_PATTERN.match(self.project_id):
            errors.append(
                f"project_id '{self.project_id}' invalid: must be 6-30 chars, "
                "start with letter, lowercase letters/numbers/hyphens only"
            )

        # Instance name
        if not self.instance_name:
            errors.append("instance_name is required")
        elif len(self.instance_name) < 4:
            errors.append(f"instance_name '{self.instance_name}' too short (min 4 chars)")
        elif not re.match(r"^[a-z0-9][a-z0-9-]*[a-z0-9]$", self.instance_name):
            errors.append(
                f"instance_name '{self.instance_name}' invalid: must start/end with "
                "alphanumeric, contain only lowercase letters, numbers, hyphens"
            )
        elif self.instance_name in FORBIDDEN_NAMES:
            errors.append(
                f"instance_name '{self.instance_name}' is forbidden (too generic, "
                f"causes naming collisions). Use a project-specific name."
            )

        # Repo prefix
        if not self.repo_prefix or self.repo_prefix == "rag-research":
            errors.append(
                f"repo_prefix '{self.repo_prefix}' looks like a default/example value. "
                "Set a project-specific prefix to avoid resource naming collisions."
            )

        # Machine type
        if self.machine_type not in VALID_MACHINE_TYPES:
            errors.append(
                f"machine_type '{self.machine_type}' not in allowed list: "
                f"{sorted(VALID_MACHINE_TYPES)}"
            )

        # PostgreSQL version
        if self.postgres_version not in VALID_POSTGRES_VERSIONS:
            errors.append(
                f"postgres_version '{self.postgres_version}' not supported. "
                f"Use one of: {sorted(VALID_POSTGRES_VERSIONS)}"
            )

        # Region
        if self.region not in VALID_REGIONS:
            errors.append(
                f"region '{self.region}' not in common regions list. "
                f"If valid, add to VALID_REGIONS. Known: {sorted(VALID_REGIONS)}"
            )

        # Zone must be in region
        if not self.zone.startswith(self.region):
            errors.append(f"zone '{self.zone}' must be in region '{self.region}'")

        # Password
        if self.postgres_db_password:
            pw = self.postgres_db_password
            if len(pw) < 12:
                errors.append("postgres_db_password must be at least 12 characters")
            if pw.lower() in ("password", "postgres", "admin", "123456"):
                errors.append("postgres_db_password is too common/weak")
        else:
            errors.append("postgres_db_password is required (set via env var or secret)")

        # GitHub repo format
        if self.github_actions_enabled and self.github_repo:
            if "/" not in self.github_repo:
                errors.append(
                    f"github_repo '{self.github_repo}' invalid: expected 'owner/repo' format"
                )

        # CIDR blocks
        for name, cidr in [("subnet_cidr", self.subnet_cidr), ("connector_cidr", self.connector_cidr)]:
            if not re.match(r"^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/\d{1,2}$", cidr):
                errors.append(f"{name} '{cidr}' is not a valid CIDR block")

        # Disk size
        if self.disk_size_gb < 10:
            errors.append(f"disk_size_gb {self.disk_size_gb} too small (min 10 GB)")
        if self.disk_size_gb > 10000:
            errors.append(f"disk_size_gb {self.disk_size_gb} too large (max 10000 GB)")

        # Init SQL file exists
        if self.init_sql and not os.path.isfile(self.init_sql):
            errors.append(f"init_sql file not found: {self.init_sql}")

        self._errors = errors
        return errors

    def is_valid(self) -> bool:
        """Return True if configuration passes all validations."""
        return len(self.validate()) == 0


def validate_module_inputs(config: Optional[PostgresConfig] = None) -> List[str]:
    """
    High-level validation entrypoint.

    Args:
        config: PostgresConfig instance. If None, loads from environment.

    Returns:
        List of error strings. Empty list means valid.
    """
    if config is None:
        config = PostgresConfig.from_env()
    return config.validate()


def validate_terraform_tfvars(path: str = "terraform.tfvars") -> List[str]:
    """
    Validate a terraform.tfvars file by extracting key variables.

    This is a lightweight check — for full validation, use Terraform's
    own `terraform validate` after generating the file.
    """
    errors: List[str] = []

    if not os.path.isfile(path):
        return [f"terraform.tfvars not found at {path}"]

    # Parse simple key = "value" lines
    values: dict = {}
    with open(path, "r") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                key, val = line.split("=", 1)
                key = key.strip()
                val = val.strip().strip('"').strip("'")
                values[key] = val

    # Check critical fields
    required = ["project_id", "postgres_db_password"]
    for field in required:
        if field not in values or not values[field]:
            errors.append(f"terraform.tfvars missing required field: {field}")

    # Check for example values
    if values.get("project_id") == "your-gcp-project":
        errors.append("project_id is still set to example value 'your-gcp-project'")
    if values.get("repo_prefix") == "rag-research":
        errors.append("repo_prefix is still set to default 'rag-research' — customize it")

    return errors


if __name__ == "__main__":
    # CLI usage: python validators/config.py
    import sys

    config = PostgresConfig.from_env()
    errors = config.validate()

    if errors:
        print("❌ Configuration errors found:", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        sys.exit(1)
    else:
        print("✅ Configuration valid")
        print(f"   Project: {config.project_id}")
        print(f"   Instance: {config.instance_name}")
        print(f"   Region: {config.region}")
        print(f"   Machine: {config.machine_type}")
        sys.exit(0)
