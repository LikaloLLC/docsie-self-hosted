#!/usr/bin/env python3
"""Check every rendered runtime image before creating billable infrastructure."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys

import yaml

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('chart')
parser.add_argument('--values', action='append', default=[])
parser.add_argument('--platform', default='linux/amd64')
args = parser.parse_args()
command = ['helm', 'template', 'docsie-preflight', args.chart]
for values in args.values:
    command += ['-f', values]
rendered = subprocess.run(command, check=True, capture_output=True, text=True).stdout
if re.search(r'^kind: EnterpriseSearch$', rendered, re.MULTILINE):
    operator_chart = Path(__file__).resolve().parents[1] / 'charts/prerequisites/eck-operator'
    rendered += subprocess.run(['helm', 'template', 'docsie-elastic-operator', str(operator_chart)],
                               check=True, capture_output=True, text=True).stdout
def image_references(node):
    # CRD schemas contain an `image:` property whose value is a schema mapping,
    # not a container reference. Parse YAML rather than matching those as text.
    if isinstance(node, dict):
        for key, value in node.items():
            if key == 'image' and isinstance(value, str) and value.strip():
                yield value
            else:
                yield from image_references(value)
    elif isinstance(node, list):
        for value in node:
            yield from image_references(value)


images = sorted({image for doc in yaml.safe_load_all(rendered) for image in image_references(doc)})
if not images:
    sys.exit('No runtime images were rendered')
failed = False
for image in images:
    result = subprocess.run(['docker', 'buildx', 'imagetools', 'inspect', image, '--raw'],
                            capture_output=True, text=True)
    if result.returncode:
        print(f'UNAVAILABLE: {image} (missing image or registry access)', file=sys.stderr)
        failed = True
        continue
    manifest = json.loads(result.stdout)
    if 'manifests' in manifest:
        platforms = {f"{m.get('platform', {}).get('os')}/{m.get('platform', {}).get('architecture')}"
                     for m in manifest['manifests']}
    else:
        # Single-manifest responses omit architecture; inspect their config.
        config = subprocess.run(['docker', 'buildx', 'imagetools', 'inspect', image,
                                 '--format', '{{json .Image}}'], capture_output=True, text=True)
        try:
            data = json.loads(config.stdout)
            platforms = {f"{data['os']}/{data['architecture']}"}
        except (ValueError, TypeError, KeyError):
            platforms = set()
    if args.platform not in platforms:
        print(f'UNSUPPORTED: {image} does not confirm {args.platform}', file=sys.stderr)
        failed = True
    else:
        print(f'OK: {image} ({args.platform})')
sys.exit(1 if failed else 0)
