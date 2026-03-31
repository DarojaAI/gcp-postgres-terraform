"""
gcp-postgres create - Provision a new PostgreSQL instance
"""

import os
import sys
import click
import logging
from pathlib import Path

from cli.terraform_runner import (
    TerraformError,
    ensure_init,
    validate,
    plan,
    apply,
    wait_for_postgres,
    get_instance_info,
    terraform_runner_log_setup,
)

logger = logging.getLogger(__name__)

# Environment variable prefix for config
ENV_PREFIX = "GCP_POSTGRES_"


def _get_config(ctx: click.Context) -> dict:
    """Build terraform var dict from CLI args and env vars."""
    config = {}

    # Required
    project_id = ctx.obj.get("project_id") or os.getenv(f"{ENV_PREFIX}PROJECT_ID")
    instance_name = ctx.obj.get("name") or os.getenv(f"{ENV_PREFIX}INSTANCE_NAME")
    db_password = ctx.obj.get("password") or os.getenv(f"{ENV_PREFIX}DB_PASSWORD")

    if not project_id:
        raise click.ClickException("--project required or set GCP_POSTGRES_PROJECT_ID")
    if not instance_name:
        raise click.ClickException("--name required or set GCP_POSTGRES_INSTANCE_NAME")
    if not db_password:
        raise click.ClickException("--password required or set GCP_POSTGRES_DB_PASSWORD")

    config["project_id"] = project_id
    config["instance_name"] = instance_name
    config["postgres_db_password"] = db_password

    # Optional overrides
    region = ctx.obj.get("region") or os.getenv(f"{ENV_PREFIX}REGION", "us-central1")
    zone = ctx.obj.get("zone") or os.getenv(f"{ENV_PREFIX}ZONE", "us-central1-b")
    postgres_version = ctx.obj.get("postgres_version") or os.getenv(f"{ENV_PREFIX}POSTGRES_VERSION", "15")
    machine_type = ctx.obj.get("machine_type") or os.getenv(f"{ENV_PREFIX}MACHINE_TYPE", "e2-micro")
    db_name = ctx.obj.get("db_name") or os.getenv(f"{ENV_PREFIX}DB_NAME", "postgres")
    db_user = ctx.obj.get("db_user") or os.getenv(f"{ENV_PREFIX}DB_USER", "postgres")
    disk_size_gb = ctx.obj.get("disk_size_gb") or int(os.getenv(f"{ENV_PREFIX}DISK_SIZE_GB", "30"))
    pgvector = ctx.obj.get("pgvector")
    if pgvector is None:
        pgvector = os.getenv(f"{ENV_PREFIX}PGVECTOR", "true").lower() == "true"

    config["region"] = region
    config["zone"] = zone
    config["postgres_version"] = postgres_version
    config["machine_type"] = machine_type
    config["postgres_db_name"] = db_name
    config["postgres_db_user"] = db_user
    config["disk_size_gb"] = disk_size_gb
    config["pgvector_enabled"] = pgvector

    # Schema injection
    init_sql = ctx.obj.get("init_sql")
    schema_file = ctx.obj.get("schema")
    if schema_file:
        schema_path = Path(schema_file)
        if not schema_path.exists():
            raise click.ClickException(f"Schema file not found: {schema_file}")
        init_sql = schema_path.read_text()
    if init_sql:
        config["init_sql"] = init_sql

    # Backup bucket
    backup_bucket = ctx.obj.get("backup_bucket") or os.getenv(f"{ENV_PREFIX}BACKUP_BUCKET", "")
    if backup_bucket:
        config["backup_bucket_name"] = backup_bucket

    # Labels
    labels_str = ctx.obj.get("labels") or os.getenv(f"{ENV_PREFIX}LABELS", "")
    if labels_str:
        labels = {}
        for pair in labels_str.split(","):
            if "=" in pair:
                k, v = pair.split("=", 1)
                labels[k.strip()] = v.strip()
        if labels:
            config["labels"] = labels

    return config


@click.command()
@click.option("--name", "name", required=True, help="Instance name (used as prefix for all resources)")
@click.option("--project", "project_id", required=True, help="GCP project ID")
@click.option("--password", "password", required=True, help="PostgreSQL database password")
@click.option("--region", default="us-central1", help="GCP region (default: us-central1)")
@click.option("--zone", default=None, help="GCP zone (default: us-central1-b)")
@click.option("--postgres-version", "--pg-version", default="15", help="PostgreSQL version: 14, 15, or 16")
@click.option("--machine-type", "--machine", default="e2-micro", help="VM machine type")
@click.option("--db-name", default="postgres", help="Database name")
@click.option("--db-user", default="postgres", help="Database user")
@click.option("--disk-size-gb", "--disk", type=int, default=30, help="Persistent disk size in GB")
@click.option("--pgvector/--no-pgvector", default=True, help="Enable pgvector extension")
@click.option("--schema", "schema", type=click.Path(exists=True), help="Path to SQL schema file to inject on startup")
@click.option("--init-sql", "init_sql", help="Inline SQL to run on startup (alternative to --schema)")
@click.option("--backup-bucket", help="GCS bucket for backups (auto-generated if not set)")
@click.option("--labels", help="Labels as k=v pairs, comma-separated (e.g. env=dev,app=mydb)")
@click.option("--dry-run", is_flag=True, help="Preview terraform plan without applying")
@click.option("--auto-approve", is_flag=True, help="Skip interactive approval")
@click.option("--no-wait", is_flag=True, help="Don't wait for PostgreSQL to be ready after creation")
@click.pass_context
def create(ctx, **kwargs):
    """
    Provision a new PostgreSQL instance on GCP Compute Engine.

    Examples:

        # Create with required options
        $ gcp-postgres create --name mydb --project my-project --password mypass

        # Create with custom PostgreSQL version and machine type
        $ gcp-postgres create --name mydb --project my-project --password mypass \\
            --postgres-version 16 --machine-type e2-small

        # Create with custom schema
        $ gcp-postgres create --name mydb --project my-project --password mypass \\
            --schema ./schema.sql

        # Dry run (preview plan)
        $ gcp-postgres create --name mydb --project my-project --password mypass --dry-run

    Environment variables can also be used (useful for CI):

        $ export GCP_POSTGRES_PROJECT_ID=my-project
        $ export GCP_POSTGRES_INSTANCE_NAME=mydb
        $ export GCP_POSTGRES_DB_PASSWORD=mypass
        $ gcp-postgres create --dry-run
    """
    terraform_runner_log_setup()

    project_id = kwargs["project_id"]
    instance_name = kwargs["name"]
    db_password = kwargs["password"]

    click.echo(f"Provisioning PostgreSQL instance '{instance_name}' in project '{project_id}'...")

    # Build vars
    config = _get_config(ctx)

    # Check required
    if not config.get("postgres_db_password"):
        raise click.ClickException("--password required or set GCP_POSTGRES_DB_PASSWORD")

    # Build extra vars for terraform
    vars_extra = {k: str(v) for k, v in config.items() if v is not None}

    working_dir = Path(__file__).parent.parent / "terraform"

    try:
        # Validate
        if not validate(working_dir=working_dir):
            raise click.ClickException("Terraform validation failed")

        # Ensure init
        click.echo("Initializing Terraform...")
        ensure_init(working_dir=working_dir)
        click.echo("Terraform initialized.")

        # Dry run
        if kwargs["dry_run"]:
            click.echo("\n--- Terraform Plan (Dry Run) ---\n")
            plan_output = plan(vars_extra=vars_extra, working_dir=working_dir)
            click.echo(plan_output)
            click.echo("\nNo changes applied (--dry-run)")
            return

        # Plan
        click.echo("\n--- Terraform Plan ---\n")
        plan_output = plan(vars_extra=vars_extra, working_dir=working_dir)
        click.echo(plan_output)

        if not kwargs["auto_approve"]:
            click.confirm("\nApply plan? This will create resources in GCP.", abort=True)

        # Apply
        click.echo("\n--- Applying Plan ---\n")
        apply(
            vars_extra=vars_extra,
            working_dir=working_dir,
            auto_approve=kwargs["auto_approve"],
        )

        # Get outputs
        click.echo("\nFetching instance information...")
        info = get_instance_info(working_dir=working_dir)

        internal_ip = info.get("internal_ip")
        external_ip = info.get("external_ip")
        db_name = config.get("postgres_db_name", "postgres")
        db_user = config.get("postgres_db_user", "postgres")

        # Wait for PostgreSQL to be ready
        if not kwargs["no_wait"] and internal_ip:
            click.echo(f"\nWaiting for PostgreSQL to be ready at {internal_ip}:5432...")
            try:
                wait_for_postgres(internal_ip, timeout=300)
                click.echo("PostgreSQL is ready!")
            except TimeoutError as e:
                click.echo(f"WARNING: {e}", err=True)
                click.echo("The instance was created but PostgreSQL may still be starting up.")
                click.echo("Run 'gcp-postgres status --name {0} --project {1}' to check.".format(
                    instance_name, project_id))

        # Success
        click.echo("\n" + "=" * 60)
        click.echo(f"✓ PostgreSQL instance '{instance_name}' created successfully!")
        click.echo("=" * 60)
        click.echo(f"\n  Instance: {instance_name}")
        click.echo(f"  Region:   {info.get('region', config.get('region'))}")
        click.echo(f"  Zone:     {info.get('zone', config.get('zone'))}")
        click.echo(f"  Internal IP: {internal_ip}")
        if external_ip:
            click.echo(f"  External IP: {external_ip}")
        click.echo(f"  Database: {db_name}")
        click.echo(f"  User:     {db_user}")
        click.echo(f"  Password: [set in Secret Manager]")
        click.echo(f"  pgvector: {'enabled' if config.get('pgvector_enabled') else 'disabled'}")
        if info.get("backup_bucket_name"):
            click.echo(f"  Backup bucket: gs://{info['backup_bucket_name']}")
        click.echo(f"\n  Connection (internal/VPC):")
        click.echo(f"    psql -h {internal_ip} -U {db_user} -d {db_name}")
        click.echo(f"\n  To check status:")
        click.echo(f"    gcp-postgres status --name {instance_name} --project {project_id}")
        click.echo(f"\n  To destroy:")
        click.echo(f"    gcp-postgres destroy --name {instance_name} --project {project_id}")
        click.echo("=" * 60)

    except TerraformError as e:
        raise click.ClickException(f"Terraform error: {e}")
    except Exception as e:
        raise click.ClickException(f"Failed to create instance: {e}")
