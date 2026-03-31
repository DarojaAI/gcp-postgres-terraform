"""
gcp-postgres CLI - Command-line interface for PostgreSQL provisioning on GCP

Usage:
    gcp-postgres create --name mydb --project my-project
    gcp-postgres status --name mydb --project my-project
    gcp-postgres connect --name mydb --project my-project
    gcp-postgres destroy --name mydb --project my-project
"""

import sys
import os
import click

# Add parent dir to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from cli.create import create
from cli.destroy import destroy
from cli.status import status
from cli.connect import connect
from cli.backup import backup


@click.group()
@click.version_option(version="0.1.0")
def cli():
    """
    gcp-postgres - PostgreSQL provisioning on GCP Compute Engine

    Examples:

        Create an instance:
        $ gcp-postgres create --name mydb --project my-project

        Check status:
        $ gcp-postgres status --name mydb --project my-project

        Get connection string:
        $ gcp-postgres connect --name mydb --project my-project

        Trigger a backup:
        $ gcp-postgres backup --name mydb --project my-project

        Destroy an instance:
        $ gcp-postgres destroy --name mydb --project my-project
    """
    pass


# Register command groups
cli.add_command(create)
cli.add_command(destroy)
cli.add_command(status)
cli.add_command(connect)
cli.add_command(backup)


if __name__ == "__main__":
    cli()
