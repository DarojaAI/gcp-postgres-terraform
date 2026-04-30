#!/usr/bin/env python3
"""Check for large files in the repository."""
import sys
from pathlib import Path


def check_large_files():
    """Check for files larger than MAX_KB."""
    MAX_KB = 5000
    large_files = []
    for f in Path('.').rglob('*'):
        if f.is_file() and '.git' not in str(f) and '.terraform' not in str(f):
            size_kb = f.stat().st_size / 1024
            if size_kb > MAX_KB:
                large_files.append(f'{f}: {size_kb:.1f}KB')

    if large_files:
        print('Large files (>5000KB):')
        for f in large_files:
            print(f'  {f}')
        sys.exit(1)


if __name__ == '__main__':
    check_large_files()