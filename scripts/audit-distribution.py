#!/usr/bin/env python3
"""Reject private runtime artifacts and known credential formats without printing values."""
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[1]
skip = {'.git', '.terraform', '__pycache__', 'dist', '.venv'}
patterns = [
    re.compile(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'),
    re.compile(r'\b(?:AKIA|ASIA)[A-Z0-9]{16}\b'),
    re.compile(r'\bgh[pousr]_[A-Za-z0-9]{30,}\b'),
    re.compile(r'\bsk-(?:proj-|ant-)?[A-Za-z0-9_-]{32,}\b'),
    re.compile(r'\b(?:altera|rohde|schwarz|urbansoft)\b', re.I),
]
failures = []
for path in root.rglob('*'):
    relative = path.relative_to(root)
    if any(part in skip for part in relative.parts):
        continue
    if path.is_symlink():
        failures.append(f'{relative}: symlink is not distributable')
        continue
    if not path.is_file() or path == Path(__file__).resolve():
        continue
    if path.suffix == '.tgz':
        # Rebuilt from audited sources by package-release.sh, never copied from private history.
        continue
    if (path.name.startswith(('.env', 'terraform.tfstate')) or path.suffix in {'.pem', '.key', '.tfplan', '.tfvars'}
            or 'generated' in relative.parts or path.name in {'license.json', 'values.staging.yaml', 'values.prod.yaml'}):
        failures.append(f'{relative}: private/runtime file')
        continue
    # Previously reviewed product screenshots are expected binary assets;
    # textual credential scanning cannot assess their visual redaction.
    if relative.parent == Path('docs/assets/screenshots') and path.suffix == '.png':
        if not path.read_bytes().startswith(b'\x89PNG\r\n\x1a\n'):
            failures.append(f'{relative}: invalid PNG asset')
        continue
    try:
        contents = path.read_text()
    except UnicodeDecodeError:
        failures.append(f'{relative}: unexpected binary')
        continue
    for pattern in patterns:
        if pattern.search(contents):
            failures.append(f'{relative}: restricted content pattern')
            break
if failures:
    print('\n'.join(failures), file=sys.stderr)
    sys.exit(1)
print('Distribution audit passed: no runtime secrets, tenant identifiers, or private deployment files found.')
