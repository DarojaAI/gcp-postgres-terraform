"""
gcp-postgres destroy - Destroy a PostgreSQL instance
"""

import os
import click
from pathlib import Path

from cli.terraform_runner import TerraformError, plan, apply, terraform_runner_log_setup


@click.command()
@click.option("--name", "name", required=True, help="Instance name to destroy")
@click.option("--project", "project_id", required=True, help="GCP project ID")
@click.option("--region", default="us-central1", help="GCP region (default: us-central1)")
@click.option("--zone", default=None, help="GCP zone (default: us-central1-b)")
@click.option("--dry-run", is_flag=True, help="Preview terraform plan without destroying")
@click.option("--auto-approve", is_flag=True, help="Skip interactive approval")
@click.pass_context
def destroy(ctx, name, project_id, region, zone, dry_run, auto_approve):
    """
    Destroy a PostgreSQL instance and all its GCP resources.

    Examples:

        # Destroy with confirmation
        $ gcp-postgres destroy --name mydb --project my-project

        # Destroy without confirmation (CI/CD)
        $ gcp-postgres destroy --name mydb --project my-project --auto-approve

        # Preview destruction plan
        $ gcp-postgres destroy --name mydb --project my-project --dry-run
    """
    terraform_runner_log_setup()

    instance_name = name

    click.echo(f"⚠️  This will DESTROY the PostgreSQL instance '{instance_name}' and ALL its resources:")
    click.echo(f"   - Compute Engine VM")
    click.echo(f"   - Persistent data disk (ALL DATA WILL BE LOST)")
    click.echo(f"   - VPC network, subnet, firewall rules")
    click.echo(f"   - Cloud Storage backup bucket")
    click.echo(f"   - Secret Manager secrets")
    click.echo(f"   - All snapshots")

    vars_extra = {
        "project_id": project_id,
        "instance_name": instance_name,
        "postgres_db_password": os.getenv("GCP_POSTGRES_DB_PASSWORD", "placeholder"),
    }
    if region:
        vars_extra["region"] = region
    if zone:
        vars_extra["zone"] = zone

    working_dir = Path(__file__).parent.parent / "terraform"

    try:
        from cli.terraform_runner import ensure_init, output
        ensure_init(working_dir=working_dir)

        # Dry run - show what would be destroyed
        if dry_run:
            click.echo("\n--- Terraform Plan (Destroy - Dry Run) ---\n")
            plan_output = plan(
                vars_extra=vars_extra,
                working_dir=working_dir,
                destroy=True,
            )
            click.echo(plan_output)
            click.echo("\nNo changes applied (--dry-run)")
            return

        # Plan first
        click.echo("\n--- Terraform Plan (Destroy) ---\n")
        plan_output = plan(
            vars_extra=vars_extra,
            working_dir=working_dir,
            destroy=True,
        )
        click.echo(plan_output)

        if not auto_approve:
            click.confirm(
                f"\n⚠️  Are you sure you want to destroy '{instance_name}'?",
                abort=True,
            )
            click.confirm(
                f"⚠️  FINAL CONFIRM: This will DELETE ALL DATA on '{instance_name}'. Continue?",
                abort=True,
            )

        # Destroy
        click.echo("\n--- Destroying Resources ---\n")
        from cli.terraform_runner import destroy
        destroy(
            vars_extra=vars_extra,
            working_dir=working_dir,
            auto_approve=auto_approve,
        )

        click.echo(f"\n✓ Instance '{instance_name}' destroyed successfully.")

    except TerraformError as e:
        raise click.ClickException(f"Terraform error: {e}")
    except click.Abort:
        click.echo("\nAborted.")
    except Exception as e:
        raise click.ClickException(f"Failed to destroy instance: {e}")
