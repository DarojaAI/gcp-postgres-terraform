#!/usr/bin/env python3
"""Check JSON syntax for all JSON files in the repository."""
import json
import sys
from pathlib import Path


def check_json_syntax():
    """Check all JSON files for syntax errors."""
    errors = []
    for f in Path('.').rglob('*.json'):
        if '.git' not in str(f) and '.terraform' not in str(f):
            try:
                with open(f) as file:
                    json.load(file)
            except Exception as e:
                errors.append(f'{f}: {e}')

    if errors:
        print('JSON errors:')
        for e in errors:
            print(f'  {e}')
        sys.exit(1)


if __name__ == '__main__':
    check_json_syntax()