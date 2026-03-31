"""
gcp-postgres backup - Trigger a manual backup
"""

import os
import click
from pathlib import Path

from cli.terraform_runner import TerraformError, terraform_runner_log_setup


@click.command()
@click.option("--name", "name", required=True, help="Instance name")
@click.option("--project", "project_id", required=True, help="GCP project ID")
@click.option("--region", default="us-central1", help="GCP region (default: us-central1)")
@click.option("--vm-user", default="ubuntu", help="SSH user for VM (default: ubuntu)")
@click.pass_context
def backup(ctx, name, project_id, region, vm_user):
    """
    Trigger an immediate on-demand backup of a PostgreSQL instance.

    The backup runs pg_dump on the instance, uploads to GCS, and reports the
    GCS path of the backup file.

    Examples:

        # Trigger backup
        $ gcp-postgres backup --name mydb --project my-project

        # List backups in GCS
        $ gsutil ls gs://pg-mydb-backups-*
    """
    terraform_runner_log_setup()

    instance_name = name
    ssh_user = vm_user

    vars_extra = {
        "project_id": project_id,
        "instance_name": instance_name,
        "postgres_db_password": os.getenv("GCP_POSTGRES_DB_PASSWORD", "placeholder"),
    }
    if region:
        vars_extra["region"] = region

    working_dir = Path(__file__).parent.parent / "terraform"

    try:
        from cli.terraform_runner import ensure_init, output

        ensure_init(working_dir=working_dir)

        try:
            backup_bucket = output("backup_bucket_name", working_dir=working_dir)
        except TerraformError:
            raise click.ClickException(
                f"Instance '{instance_name}' not found. Has it been created?"
            )

        zone = output("zone", working_dir=working_dir)
        ssh_cmd = output("ssh_command", working_dir=working_dir)
        db_name = output_json_try("postgres_db_name", working_dir=working_dir) or "postgres"

        click.echo(f"Triggering backup for '{instance_name}'...")

        # SSH into the VM and run the backup script
        backup_cmd = f"sudo /opt/postgres-backup/backup.sh"

        # Build SSH command
        ssh_full = ssh_cmd.replace("gcloud compute ssh", f"gcloud compute ssh --zone={zone}")
        # Add the backup command at the end
        full_cmd = f"{ssh_full} --command='{backup_cmd}'"

        click.echo(f"Running backup on VM (this may take a few minutes)...")

        import subprocess
        result = subprocess.run(
            full_cmd,
            shell=True,
            capture_output=True,
            text=True,
            timeout=300,  # 5 min timeout
        )

        if result.returncode != 0:
            raise click.ClickException(
                f"Backup failed:\n{result.stderr or result.stdout}"
            )

        output_text = result.stdout.strip()

        # Parse backup filename from output
        backup_file = None
        for line in output_text.split("\n"):
            if "gs://" in line:
                backup_file = line.strip()
                break

        if not backup_file:
            # Try to construct it
            import datetime
            timestamp = datetime.datetime.utcnow().strftime("%Y-%m-%d_%H-%M-%S")
            backup_file = f"gs://{backup_bucket}/pgbackup_{db_name}_{timestamp}.sql.gz"

        click.echo(f"\n✓ Backup completed!")
        click.echo(f"\n  Backup file: {backup_file}")
        click.echo(f"\n  To restore from backup:")
        click.echo(f"    gsutil cp {backup_file} /tmp/restore.sql.gz")
        click.echo(f"    gunzip /tmp/restore.sql.gz")
        click.echo(f"    psql -h <host> -U <user> -d <database> -f /tmp/restore.sql")
        click.echo(f"\n  To list all backups:")
        click.echo(f"    gsutil ls gs://{backup_bucket}/")

    except TerraformError as e:
        raise click.ClickException(f"Terraform error: {e}")
    except subprocess.TimeoutExpired:
        raise click.ClickException("Backup timed out after 5 minutes")
    except Exception as e:
        raise click.ClickException(f"Failed to trigger backup: {e}")


def output_json_try(key: str, working_dir: Path) -> str:
    """Try to get terraform output as raw string."""
    from cli.terraform_runner import output
    try:
        return output(key, working_dir=working_dir)
    except TerraformError:
        return None
