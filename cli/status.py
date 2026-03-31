"""
gcp-postgres status - Check instance status
"""

import os
import click
import json
from pathlib import Path

from cli.terraform_runner import TerraformError, terraform_runner_log_setup


@click.command()
@click.option("--name", "name", required=True, help="Instance name")
@click.option("--project", "project_id", required=True, help="GCP project ID")
@click.option("--region", default="us-central1", help="GCP region (default: us-central1)")
@click.option("--output-format", "--format", "output_format",
              type=click.Choice(["text", "json"]),
              default="text", help="Output format")
@click.pass_context
def status(ctx, name, project_id, region, output_format):
    """
    Check the status of a PostgreSQL instance.

    Examples:

        # Check instance status
        $ gcp-postgres status --name mydb --project my-project

        # JSON output for scripting
        $ gcp-postgres status --name mydb --project my-project --output-format json
    """
    terraform_runner_log_setup()

    instance_name = name

    vars_extra = {
        "project_id": project_id,
        "instance_name": instance_name,
        "postgres_db_password": os.getenv("GCP_POSTGRES_DB_PASSWORD", "placeholder"),
    }
    if region:
        vars_extra["region"] = region

    working_dir = Path(__file__).parent.parent / "terraform"

    try:
        from cli.terraform_runner import ensure_init, get_instance_info

        ensure_init(working_dir=working_dir)
        info = get_instance_info(working_dir=working_dir)

        # Filter out None values
        info_clean = {k: v for k, v in info.items() if v is not None}

        if output_format == "json":
            click.echo(json.dumps(info_clean, indent=2))
            return

        # Text output
        click.echo(f"\nPostgreSQL Instance: {instance_name}")
        click.echo(f"{'=' * 50}")

        if not any(info_clean.values()):
            click.echo("No outputs found. Has this instance been created with Terraform?")
            click.echo(f"\nTo create: gcp-postgres create --name {instance_name} --project {project_id}")
            return

        fields = [
            ("Instance Name", "instance_name"),
            ("Project", "project_id"),
            ("Region", "region"),
            ("Zone", "zone"),
            ("Internal IP", "internal_ip"),
            ("External IP", "external_ip"),
            ("Machine Type", "machine_type"),
            ("Disk Size (GB)", "disk_size_gb"),
            ("PostgreSQL Version", "postgres_version"),
            ("pgvector", "pgvector_enabled"),
            ("Database", "postgres_db_name"),
            ("User", "postgres_db_user"),
            ("Backup Bucket", "backup_bucket_name"),
            ("Service Account", "service_account_email"),
        ]

        for label, key in fields:
            if key in info_clean and info_clean[key]:
                click.echo(f"  {label}: {info_clean[key]}")

        click.echo(f"\n  Connection (internal):")
        if info_clean.get("psql_command_internal"):
            click.echo(f"    {info_clean['psql_command_internal']}")

        if info_clean.get("ssh_command"):
            click.echo(f"\n  SSH command:")
            click.echo(f"    {info_clean['ssh_command']}")

        click.echo(f"\n  Terraform metadata:")
        for key, value in info_clean.items():
            if key not in [k for _, k in fields] and value and key not in ["ssh_command", "psql_command_internal"]:
                click.echo(f"    {key}: {value}")

        click.echo(f"\n  To connect:")
        click.echo(f"    gcp-postgres connect --name {instance_name} --project {project_id}")
        click.echo(f"\n  To destroy:")
        click.echo(f"    gcp-postgres destroy --name {instance_name} --project {project_id}")

    except TerraformError as e:
        raise click.ClickException(f"Terraform error: {e}")
    except Exception as e:
        raise click.ClickException(f"Failed to get status: {e}")
