#!/usr/bin/env bash
# Build public deployment artifacts only. Container images remain separately licensed.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
python3 scripts/audit-distribution.py
python3 -m unittest discover -s tests -v
mkdir -p dist
helm dependency build charts/docsie-platform --skip-refresh
helm package charts/docsie --destination dist
helm package charts/docsie-platform --destination dist
helm repo index dist --url https://github.com/LikaloLLC/docsie-self-hosted/releases/download/v0.2.0-preview.1
python3 - <<'PY'
import hashlib
from pathlib import Path
root = Path('dist')
with (root / 'SHA256SUMS').open('w') as output:
    for path in sorted(root.glob('*.tgz')):
        output.write(f'{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}\n')
PY
echo 'Chart packages and checksums are in dist/. These are not an offline image bundle.'
