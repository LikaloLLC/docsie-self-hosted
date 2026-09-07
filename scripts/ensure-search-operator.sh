#!/usr/bin/env bash
# Bootstrap a pinned, vendored ECK prerequisite on an explicit cluster.
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
[[ $# -eq 1 ]] || { echo 'Usage: ensure-search-operator.sh KUBECONFIG' >&2; exit 2; }
config=$1
[[ -f "$config" ]] || { echo 'Kubeconfig must exist' >&2; exit 2; }
if kubectl --kubeconfig "$config" get crd enterprisesearches.enterprisesearch.k8s.elastic.co >/dev/null 2>&1; then
  echo 'Existing ECK CRDs detected; reusing the cluster operator. It must watch the Docsie namespace.'
  exit 0
fi
# Never overwrite a partial/existing Elastic installation with a second owner.
if kubectl --kubeconfig "$config" get crd elasticsearches.elasticsearch.k8s.elastic.co >/dev/null 2>&1; then
  echo 'Existing Elasticsearch CRDs lack Enterprise Search support. Configure the existing ECK operator first.' >&2
  exit 1
fi
helm upgrade --install docsie-elastic-operator "$ROOT/charts/prerequisites/eck-operator" \
  --kubeconfig "$config" --namespace docsie-system --create-namespace \
  --set telemetry.disabled=true --wait --timeout 5m
kubectl --kubeconfig "$config" wait --for=condition=Established \
  crd/enterprisesearches.enterprisesearch.k8s.elastic.co --timeout=60s
