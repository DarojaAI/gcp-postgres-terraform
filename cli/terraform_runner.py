"""
Terraform runner - shared wrapper for Terraform operations

Handles:
- Locating Terraform modules
- Running terraform init/plan/apply/destroy
- Polling for instance readiness
- Error handling and output parsing
"""

import subprocess
import os
import time
import json
from pathlib import Path
from typing import Optional, Dict, Any, List
import logging

logger = logging.getLogger(__name__)


def terraform_runner_log_setup(level: int = logging.INFO):
    """Configure logging for terraform runner."""
    logging.basicConfig(
        level=level,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
        datefmt="%H:%M:%S",
    )

# Path to the terraform directory within the package
TERRAFORM_DIR = Path(__file__).parent.parent / "terraform"


class TerraformError(Exception):
    """Raised when a Terraform operation fails"""
    pass


class InstanceNotFoundError(Exception):
    """Raised when an instance is not found"""
    pass


def run_terraform(
    args: List[str],
    cwd: Path = TERRAFORM_DIR,
    capture: bool = True,
    check: bool = True,
    env_extra: Optional[Dict[str, str]] = None,
) -> subprocess.CompletedProcess:
    """
    Run a terraform command with error handling.

    Args:
        args: Terraform command arguments (e.g. ['init'], ['apply', '-var-file=dev.tfvars'])
        cwd: Working directory for terraform
        capture: Capture stdout/stderr
        check: Raise TerraformError on non-zero exit
        env_extra: Additional environment variables

    Returns:
        CompletedProcess object

    Raises:
        TerraformError: If terraform returns non-zero exit (check=True)
    """
    cmd = ["terraform"] + args

    env = os.environ.copy()
    if env_extra:
        env.update(env_extra)

    logger.debug(f"Running: {' '.join(cmd)} in {cwd}")

    try:
        result = subprocess.run(
            cmd,
            cwd=str(cwd),
            capture_output=capture,
            text=True,
            env=env,
        )
    except FileNotFoundError:
        raise TerraformError(
            "terraform not found. Is Terraform installed and in PATH?\n"
            "Install: https://developer.hashicorp.com/terraform/downloads"
        )
    except Exception as e:
        raise TerraformError(f"Failed to run terraform: {e}")

    if check and result.returncode != 0:
        raise TerraformError(
            f"terraform {' '.join(args)} failed (exit {result.returncode}):\n"
            f"{result.stderr or result.stdout}"
        )

    return result


def init(working_dir: Path = TERRAFORM_DIR, backend_config: Optional[Dict[str, str]] = None) -> None:
    """
    Initialize Terraform (downloads providers, sets up backend).

    Args:
        working_dir: Directory containing terraform files
        backend_config: Backend config values (bucket, prefix)
    """
    args = ["init"]
    if backend_config:
        for key, value in backend_config.items():
            args.extend(["-backend-config", f"{key}={value}"])

    result = run_terraform(args, cwd=working_dir, check=True)
    logger.info("Terraform initialized successfully")


def validate(working_dir: Path = TERRAFORM_DIR) -> bool:
    """
    Validate Terraform configuration syntax.

    Args:
        working_dir: Directory containing terraform files

    Returns:
        True if valid
    """
    result = run_terraform(["validate"], cwd=working_dir, check=True)
    return "The configuration is valid" in result.stdout


def plan(
    var_file: Optional[str] = None,
    vars_extra: Optional[Dict[str, str]] = None,
    working_dir: Path = TERRAFORM_DIR,
    destroy: bool = False,
) -> str:
    """
    Generate Terraform plan.

    Args:
        var_file: Path to .tfvars file
        vars_extra: Extra -var flags
        working_dir: Terraform directory
        destroy: Generate destruction plan

    Returns:
        Plan summary from terraform
    """
    args = ["plan", "-out=tfplan"]
    if var_file:
        args.extend(["-var-file", var_file])
    if vars_extra:
        for key, value in vars_extra.items():
            args.extend(["-var", f"{key}={value}"])
    if destroy:
        args.append("-destroy")

    result = run_terraform(args, cwd=working_dir, check=True)
    return result.stdout


def apply(
    plan_file: str = "tfplan",
    var_file: Optional[str] = None,
    vars_extra: Optional[Dict[str, str]] = None,
    working_dir: Path = TERRAFORM_DIR,
    auto_approve: bool = False,
) -> None:
    """
    Apply Terraform plan.

    Args:
        plan_file: Plan file from terraform plan
        var_file: Path to .tfvars file
        vars_extra: Extra -var flags
        working_dir: Terraform directory
        auto_approve: Skip interactive approval
    """
    args = ["apply"]
    if auto_approve:
        args.append("-auto-approve")
    args.append(plan_file)
    if var_file:
        args.extend(["-var-file", var_file])
    if vars_extra:
        for key, value in vars_extra.items():
            args.extend(["-var", f"{key}={value}"])

    result = run_terraform(args, cwd=working_dir, check=True)
    logger.info("Terraform apply completed")


def destroy(
    var_file: Optional[str] = None,
    vars_extra: Optional[Dict[str, str]] = None,
    working_dir: Path = TERRAFORM_DIR,
    auto_approve: bool = False,
) -> None:
    """
    Destroy all Terraform-managed resources.

    Args:
        var_file: Path to .tfvars file
        vars_extra: Extra -var flags
        working_dir: Terraform directory
        auto_approve: Skip interactive approval
    """
    args = ["destroy"]
    if auto_approve:
        args.append("-auto-approve")
    if var_file:
        args.extend(["-var-file", var_file])
    if vars_extra:
        for key, value in vars_extra.items():
            args.extend(["-var", f"{key}={value}"])

    run_terraform(args, cwd=working_dir, check=True)
    logger.info("Terraform destroy completed")


def output(key: str, working_dir: Path = TERRAFORM_DIR) -> str:
    """
    Get a terraform output value.

    Args:
        key: Output variable name
        working_dir: Terraform directory

    Returns:
        Output value as string
    """
    result = run_terraform(["output", "-raw", key], cwd=working_dir, check=True)
    return result.stdout.strip()


def output_json(key: str, working_dir: Path = TERRAFORM_DIR) -> Any:
    """
    Get a terraform output value as parsed JSON.

    Args:
        key: Output variable name
        working_dir: Terraform directory

    Returns:
        Parsed JSON value
    """
    result = run_terraform(["output", "-json", key], cwd=working_dir, check=True)
    return json.loads(result.stdout.strip())


def get_instance_info(var_file: str, working_dir: Path = TERRAFORM_DIR) -> Dict[str, Any]:
    """
    Get all relevant instance information from terraform outputs.

    Returns:
        Dict with instance_name, region, zone, internal_ip, external_ip,
        connection_string, etc.
    """
    keys = [
        "instance_name",
        "project_id",
        "region",
        "zone",
        "internal_ip",
        "external_ip",
        "connection_string_internal",
        "psql_command_internal",
        "psql_command_external",
        "ssh_command",
        "backup_bucket_name",
        "postgres_version",
        "pgvector_enabled",
        "machine_type",
        "disk_size_gb",
        "service_account_email",
    ]

    info = {}
    for key in keys:
        try:
            info[key] = output(key, working_dir=working_dir)
        except TerraformError:
            # Output might not exist if terraform hasn't been applied
            info[key] = None

    return info


def wait_for_postgres(
    internal_ip: str,
    port: int = 5432,
    timeout: int = 300,
    poll_interval: int = 10,
) -> bool:
    """
    Wait for PostgreSQL to become responsive.

    Args:
        internal_ip: PostgreSQL host IP
        port: PostgreSQL port
        timeout: Max seconds to wait
        poll_interval: Seconds between polls

    Returns:
        True if PostgreSQL became ready

    Raises:
        TimeoutError: If PostgreSQL didn't become ready within timeout
    """
    import socket

    start = time.time()
    while time.time() - start < timeout:
        try:
            sock = socket.create_connection((internal_ip, port), timeout=5)
            sock.close()
            logger.info(f"PostgreSQL is ready at {internal_ip}:{port}")
            return True
        except (socket.timeout, ConnectionRefusedError, OSError):
            logger.debug(f"PostgreSQL not ready yet (attempt {(time.time()-start)/poll_interval:.0f}), retrying...")
            time.sleep(poll_interval)

    raise TimeoutError(
        f"PostgreSQL did not become ready within {timeout}s at {internal_ip}:{port}"
    )


def ensure_init(
    var_file: Optional[str] = None,
    vars_extra: Optional[Dict[str, str]] = None,
    working_dir: Path = TERRAFORM_DIR,
) -> None:
    """
    Ensure terraform is initialized (run init if needed).

    Args:
        var_file: Path to .tfvars file
        vars_extra: Extra -var flags
        working_dir: Terraform directory
    """
    try:
        run_terraform(["state pull"], cwd=working_dir, check=False)
    except TerraformError:
        # Not initialized yet
        backend_config = None
        if var_file and "terraform.tfvars" not in var_file:
            # Assume GCS backend config from .tfbackend file if present
            tfbackend = working_dir / "terraform.tfbackend"
            if tfbackend.exists():
                backend_config = {}
                for line in tfbackend.read_text().strip().split("\n"):
                    if "=" in line:
                        k, v = line.split("=", 1)
                        backend_config[k.strip()] = v.strip()
        init(working_dir=working_dir, backend_config=backend_config)
