"""
gcp-postgres connect - Get connection information for an instance
"""

import os
import click
import subprocess
from pathlib import Path

from cli.terraform_runner import TerraformError, terraform_runner_log_setup


@click.command()
@click.option("--name", "name", required=True, help="Instance name")
@click.option("--project", "project_id", required=True, help="GCP project ID")
@click.option("--region", default="us-central1", help="GCP region (default: us-central1)")
@click.option("--db-name", help="Database name override")
@click.option("--db-user", help="Database user override")
@click.option("--get-password", "get_password", is_flag=True,
              help="Retrieve password from Secret Manager and print (DANGER: prints password)")
@click.option("--psql", is_flag=True, help="Open psql shell directly (requires psql installed)")
@click.pass_context
def connect(ctx, name, project_id, region, db_name, db_user, get_password, psql):
    """
    Get connection information for a PostgreSQL instance.

    Examples:

        # Get connection string
        $ gcp-postgres connect --name mydb --project my-project

        # Open psql shell directly (requires psql installed and password in PG_PASSWORD env var)
        $ gcp-postgres connect --name mydb --project my-project --psql

        # Get password from Secret Manager and print (for scripting)
        $ gcp-postgres connect --name mydb --project my-project --get-password
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
        from cli.terraform_runner import ensure_init, output, output_json

        ensure_init(working_dir=working_dir)

        # Get connection info from terraform output
        try:
            internal_ip = output("internal_ip", working_dir=working_dir)
        except TerraformError:
            raise click.ClickException(
                f"Instance '{instance_name}' not found. Has it been created?\n"
                f"Run: gcp-postgres create --name {instance_name} --project {project_id}"
            )

        try:
            external_ip = output("external_ip", working_dir=working_dir)
        except TerraformError:
            external_ip = None

        try:
            conn_info = output_json("connection_info", working_dir=working_dir)
        except TerraformError:
            conn_info = {"host": internal_ip, "port": 5432}

        host = internal_ip
        if not host:
            raise click.ClickException("Could not determine instance IP")

        db_override = db_name or os.getenv("GCP_POSTGRES_DB_NAME")
        user_override = db_user or os.getenv("GCP_POSTGRES_DB_USER")
        database = db_override or conn_info.get("database", "postgres")
        user = user_override or conn_info.get("user", "postgres")
        port = conn_info.get("port", 5432)

        if psql:
            # Try to get password from Secret Manager
            password = os.getenv("PGPASSWORD") or os.getenv("GCP_POSTGRES_DB_PASSWORD")
            if not password:
                try:
                    import subprocess
                    result = subprocess.run(
                        ["gcloud", "secrets", "versions", "access",
                         "--secret", f"{instance_name}_POSTGRES_PASSWORD",
                         "--project", project_id],
                        capture_output=True, text=True, timeout=10
                    )
                    if result.returncode == 0:
                        password = result.stdout.strip()
                except Exception:
                    pass

            if not password:
                raise click.ClickException(
                    "Password not available. Set PGPASSWORD env var or --get-password"
                )

            env = os.environ.copy()
            env["PGPASSWORD"] = password
            env["PGHOST"] = host
            env["PGPORT"] = str(port)
            env["PGUSER"] = user
            env["PGDATABASE"] = database

            click.echo(f"Connecting to {host}:{port}/{database} as {user}...")

            try:
                subprocess.run(["psql"], env=env)
            except FileNotFoundError:
                raise click.ClickException(
                    "psql not found. Install with: apt install postgresql-client"
                )
            return

        # Just print connection info
        click.echo(f"\nPostgreSQL Connection Info - {instance_name}")
        click.echo(f"{'=' * 50}")

        click.echo(f"\n  Internal (from VPC/Cloud Run):")
        click.echo(f"    Host:     {host}")
        click.echo(f"    Port:     {port}")
        click.echo(f"    Database: {database}")
        click.echo(f"    User:     {user}")

        if external_ip:
            click.echo(f"\n  External (direct internet access):")
            click.echo(f"    Host:     {external_ip}")
            click.echo(f"    Port:     {port}")

        click.echo(f"\n  Connection strings:")

        # psql commands
        cmd_internal = f"psql -h {host} -U {user} -d {database}"
        click.echo(f"    psql (internal):  {cmd_internal}")

        if external_ip:
            cmd_external = f"psql -h {external_ip} -U {user} -d {database}"
            click.echo(f"    psql (external):  {cmd_external}")

        # Python
        python_conn = f"postgresql://{user}@[{host}]:{port}/{database}"
        click.echo(f"    Python:  {python_conn}")

        # Environment variables
        click.echo(f"\n  Environment variables:")
        click.echo(f"    export PGHOST={host}")
        click.echo(f"    export PGPORT={port}")
        click.echo(f"    export PGDATABASE={database}")
        click.echo(f"    export PGUSER={user}")
        click.echo(f"    export PGPASSWORD=<from Secret Manager>")

        click.echo(f"\n  To get password from Secret Manager:")
        click.echo(f"    gcloud secrets versions access \\")
        click.echo(f"      --secret={instance_name}_POSTGRES_PASSWORD \\")
        click.echo(f"      --project={project_id}")

        if external_ip:
            click.echo(f"\n  NOTE: External IP is assigned. Ensure your IP is in")
            click.echo(f"  'allow_postgres_from_cidrs' to connect externally.")

    except TerraformError as e:
        raise click.ClickException(f"Terraform error: {e}")
    except Exception as e:
        raise click.ClickException(f"Failed to get connection info: {e}")
