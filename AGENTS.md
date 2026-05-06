# AGENTS.md - gcp-postgres-terraform

## Build/Lint/Test Commands

**Terraform (before any *.tf commit):**
- `terraform fmt -check -diff` - format check
- `terraform init -backend=false` - syntax validation
- `terraform validate` - full validation
- `grep -rn 'backend "' .` - verify NO backend blocks (module constraint)

**Pre-commit (runs all hooks):**
- `pre-commit run --all-files`

**Python:**
- `pip install -r requirements.txt` - install deps
- `python -m pytest tests/` - run all tests
- `python -m pytest tests/test_file.py::test_function` - run single test
- `python -m pytest tests/ -v` - verbose output

## Code Style Guidelines

**Terraform:**
- Use `terraform fmt` for formatting
- NO backend blocks in module (consumer provides backend)
- Use full resource IDs (network_id, subnet_id) to avoid count non-determinism
- Mark sensitive variables with `sensitive = true`

**Python:**
- Use type hints where practical
- Follow PEP 8 naming: snake_case for functions/variables, PascalCase for classes
- Use Click for CLI commands (see cli/main.py pattern)
- Import order: stdlib, third-party, local (see cli/main.py:11-22)
- Use descriptive docstrings for modules and functions

**General:**
- Conventional commits: `fix:`, `feat:`, `feat!:`, `docs:`, `chore:`, `refactor:`
- Never commit secrets or credentials
- Run pre-commit hooks before committing
