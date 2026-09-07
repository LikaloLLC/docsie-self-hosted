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
# Inspect the effective rendered profile without writing generated Secrets to disk.
if helm template docsie "$ROOT/charts/docsie-platform" --namespace "$namespace" --values "$values" | \
    awk '/^kind: EnterpriseSearch$/ {found=1} END {exit !found}'; then
  bash "$ROOT/scripts/ensure-search-operator.sh" "$config"
fi
helm upgrade --install docsie "$ROOT/charts/docsie-platform" \
  --kubeconfig "$config" --namespace "$namespace" --create-namespace \
  --values "$values" --wait --wait-for-jobs --timeout "${DOCSIE_INSTALL_TIMEOUT:-40m}"
helm test docsie --filter name=docsie-search-test --kubeconfig "$config" --namespace "$namespace" --logs --timeout 3m
# Only run the speech test when the optional local server is installed.
if kubectl --kubeconfig "$config" --namespace "$namespace" get deployment chatterbox-tts >/dev/null 2>&1; then
  helm test docsie --filter name=docsie-chatterbox-test --kubeconfig "$config" --namespace "$namespace" --logs --timeout 11m
fi
kubectl --kubeconfig "$config" --namespace "$namespace" get pods
