#!/usr/bin/env bash
# Install the platform into an explicitly selected, already provisioned cluster.
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
if [[ $# -ne 3 ]]; then
  echo "Usage: $0 KUBECONFIG NAMESPACE VALUES_FILE" >&2
  exit 2
fi
config=$1
namespace=$2
values=$3
[[ -f "$config" && -f "$values" ]] || { echo "Kubeconfig and values must exist" >&2; exit 2; }
[[ "$namespace" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]] || { echo "Invalid namespace" >&2; exit 2; }
for tool in helm kubectl; do command -v "$tool" >/dev/null; done
kubectl --kubeconfig "$config" get --raw=/readyz >/dev/null
helm dependency build "$ROOT/charts/docsie-platform" --skip-refresh
helm upgrade --install docsie "$ROOT/charts/docsie-platform" \
  --kubeconfig "$config" --namespace "$namespace" --create-namespace \
  --values "$values" --wait --timeout 20m
kubectl --kubeconfig "$config" --namespace "$namespace" get pods
