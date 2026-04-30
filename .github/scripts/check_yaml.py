#!/usr/bin/env python3
"""Check YAML syntax for all YAML files in the repository."""
import yaml
import sys
from pathlib import Path


def check_yaml_syntax():
    """Check all YAML files for syntax errors."""
    errors = []
    for f in Path('.').rglob('*.y*ml'):
        if '.git' not in str(f) and '.terraform' not in str(f):
            try:
                with open(f) as file:
                    yaml.safe_load(file)
            except Exception as e:
                errors.append(f'{f}: {e}')

    if errors:
        print('YAML errors:')
        for e in errors:
            print(f'  {e}')
        sys.exit(1)


if __name__ == '__main__':
    check_yaml_syntax()