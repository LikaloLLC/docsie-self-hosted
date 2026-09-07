#!/usr/bin/env bash
# docsie-platform on-prem installer.
#
# Layout expectations (docsie-onprem bundle, see docs/ONPREM_INSTALLER_DESIGN.md §3.2):
#   <bundle>/scripts/install.sh          (this file)
#   <bundle>/charts/docsie-platform-<v>.tgz   OR a docsie-platform/ chart dir
#   <bundle>/images/oci-layout/          (optional; imported into containerd)
#   <bundle>/k3s/k3s <arch> binary + airgap images (optional; k3s bootstrap)
#   <bundle>/config/docsie-onprem.env    (optional; extra --values/--set input)
#
# No network access is assumed at any point.
set -euo pipefail

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE_ROOT="$(cd "${SCRIPT_ROOT}/.." && pwd)"

PROFILE="kb"
NAMESPACE="${DOCSIE_NAMESPACE:-docsie}"
RELEASE="${DOCSIE_RELEASE:-docsie-platform}"
VALUES_FILE=""
HOSTNAME_ARG=""
MODEL_ENDPOINT=""
SKIP_VERIFY=0

usage() {
  cat <<'EOF'
Usage: install.sh [options]
  --profile kb|kb-ai|full   Install profile (default: kb)
  --hostname <fqdn>         Public hostname (sets global.hostname)
  --model-endpoint <url>    OpenAI-compatible model endpoint (global.modelEndpoint)
  --namespace <ns>          Target namespace (default: docsie)
  --release <name>          Helm release name (default: docsie-platform)
  --values <file>           Extra values file layered on top
  --skip-verify             Do not run verify.sh after install
  -h, --help                This help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="${2:?--profile needs a value}"; shift 2 ;;
    --hostname) HOSTNAME_ARG="${2:?}"; shift 2 ;;
    --model-endpoint) MODEL_ENDPOINT="${2:?}"; shift 2 ;;
    --namespace) NAMESPACE="${2:?}"; shift 2 ;;
    --release) RELEASE="${2:?}"; shift 2 ;;
    --values) VALUES_FILE="${2:?}"; shift 2 ;;
    --skip-verify) SKIP_VERIFY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

case "${PROFILE}" in
  kb|kb-ai|full) ;;
  *) echo "Invalid --profile '${PROFILE}' (kb|kb-ai|full)." >&2; exit 2 ;;
esac
if [[ -n "${VALUES_FILE}" && ! -f "${VALUES_FILE}" ]]; then
  echo "Values file not found: ${VALUES_FILE}" >&2; exit 2
fi

log()  { printf '[install] %s\n' "$*"; }
fail() { printf '[install] ERROR: %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------- k3s bootstrap
ensure_k3s() {
  if command -v kubectl >/dev/null 2>&1 && kubectl version >/dev/null 2>&1; then
    log "Kubernetes reachable; skipping k3s bootstrap."
    return
  fi
  local arch k3s_bin
  case "$(uname -m)" in
    x86_64) arch=amd64 ;;
    aarch64|arm64) arch=arm64 ;;
    *) fail "Unsupported architecture: $(uname -m)" ;;
  esac
  k3s_bin="${BUNDLE_ROOT}/k3s/k3s-${arch}"
  [[ -x "${k3s_bin}" ]] || k3s_bin="${BUNDLE_ROOT}/k3s/k3s"
  if [[ ! -x "${k3s_bin}" ]]; then
    fail "No Kubernetes cluster reachable and no bundled k3s binary at ${BUNDLE_ROOT}/k3s/. \
Install k3s yourself or add the k3s airgap artifacts to the bundle."
  fi
  [[ "$(id -u)" -eq 0 ]] || fail "k3s bootstrap requires root (re-run with sudo)."
  log "Bootstrapping k3s from bundle..."
  install -m 0755 "${k3s_bin}" /usr/local/bin/k3s
  # Airgap images for k3s' own components (pause, coredns, traefik, ...)
  if compgen -G "${BUNDLE_ROOT}/k3s/k3s-airgap-images-*.tar*" >/dev/null; then
    mkdir -p /var/lib/rancher/k3s/agent/images
    cp "${BUNDLE_ROOT}"/k3s/k3s-airgap-images-*.tar* /var/lib/rancher/k3s/agent/images/
  fi
  if [[ -f "${BUNDLE_ROOT}/k3s/install.sh" ]]; then
    INSTALL_K3S_SKIP_DOWNLOAD=true sh "${BUNDLE_ROOT}/k3s/install.sh"
  else
    fail "Bundled k3s install script missing (${BUNDLE_ROOT}/k3s/install.sh)."
  fi
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
  local i
  for i in $(seq 1 60); do
    kubectl get nodes >/dev/null 2>&1 && break
    sleep 2
  done
  kubectl get nodes >/dev/null 2>&1 || fail "k3s did not become ready."
  log "k3s is up."
}

# ------------------------------------------------------------- image import
import_images() {
  local layout="${BUNDLE_ROOT}/images/oci-layout"
  if [[ ! -d "${layout}" ]]; then
    log "No bundled images at ${layout}; assuming images are already present."
    return
  fi
  local ctr=""
  if command -v ctr >/dev/null 2>&1; then
    ctr="ctr"
  elif command -v k3s >/dev/null 2>&1; then
    ctr="k3s ctr"
  else
    fail "Bundled images present but no ctr/k3s binary to import them with."
  fi
  log "Importing bundled images into containerd..."
  local tarball imported=0
  # Either a directory of per-image OCI tars, or one combined archive.
  if compgen -G "${layout}"/*.tar >/dev/null; then
    for tarball in "${layout}"/*.tar; do
      ${ctr} -n k8s.io images import --all-platforms "${tarball}" >/dev/null
      imported=$((imported + 1))
    done
  elif [[ -f "${layout}/index.json" ]]; then
    # Single OCI layout directory: pack-free import via a tar stream.
    tar -C "${layout}" -cf - . | ${ctr} -n k8s.io images import --all-platforms - >/dev/null
    imported=1
  else
    fail "images/oci-layout exists but contains neither *.tar files nor an OCI index.json."
  fi
  log "Imported ${imported} image archive(s)."
}

# ------------------------------------------------------------- helm install
helm_install() {
  command -v helm >/dev/null 2>&1 || fail "helm is required on the install host (bundle it or install it)."
  local chart=""
  if compgen -G "${BUNDLE_ROOT}/charts/docsie-platform-*.tgz" >/dev/null; then
    chart="$(ls -1 "${BUNDLE_ROOT}"/charts/docsie-platform-*.tgz | sort -V | tail -1)"
  elif [[ -f "${BUNDLE_ROOT}/charts/docsie-platform/Chart.yaml" ]]; then
    chart="${BUNDLE_ROOT}/charts/docsie-platform"
  else
    fail "No docsie-platform chart found under ${BUNDLE_ROOT}/charts/."
  fi

  local -a set_flags=()
  set_flags+=(--set "profiles.kb=true")
  case "${PROFILE}" in
    kb-ai) set_flags+=(--set "profiles.kbAi=true") ;;
    full)  set_flags+=(--set "profiles.kbAi=true" --set "profiles.full=true") ;;
  esac
  [[ -n "${HOSTNAME_ARG}" ]] && set_flags+=(--set "global.hostname=${HOSTNAME_ARG}")
  [[ -n "${MODEL_ENDPOINT}" ]] && set_flags+=(--set "global.modelEndpoint=${MODEL_ENDPOINT}")

  local -a values_flags=()
  if [[ -f "${BUNDLE_ROOT}/config/docsie-onprem.values.yaml" ]]; then
    values_flags+=(--values "${BUNDLE_ROOT}/config/docsie-onprem.values.yaml")
  fi
  [[ -n "${VALUES_FILE}" ]] && values_flags+=(--values "${VALUES_FILE}")

  log "Installing chart ${chart} (profile: ${PROFILE}) into ${NAMESPACE}/${RELEASE}..."
  if [[ -d "$chart" ]]; then helm dependency build "$chart" >/dev/null; fi
  if helm template "${RELEASE}" "${chart}" "${set_flags[@]}" ${values_flags[@]+"${values_flags[@]}"} | \
      awk '/^kind: EnterpriseSearch$/ {found=1} END {exit !found}'; then
    if ! kubectl get crd enterprisesearches.enterprisesearch.k8s.elastic.co >/dev/null 2>&1; then
      if kubectl get crd elasticsearches.elasticsearch.k8s.elastic.co >/dev/null 2>&1; then
        fail "Existing Elastic installation lacks Enterprise Search CRDs; configure its operator first."
      fi
      local operator_chart="${BUNDLE_ROOT}/charts/eck-operator-2.16.1.tgz"
      [[ -f "$operator_chart" ]] || fail "Bundle must include charts/eck-operator-2.16.1.tgz and its container image."
      helm upgrade --install docsie-elastic-operator "$operator_chart" \
        --namespace docsie-system --create-namespace --wait --timeout 5m
    fi
  fi
  helm upgrade --install "${RELEASE}" "${chart}" \
    --namespace "${NAMESPACE}" --create-namespace \
    "${set_flags[@]}" \
    ${values_flags[@]+"${values_flags[@]}"} \
    --wait --wait-for-jobs --timeout 20m
  kubectl -n "$NAMESPACE" exec deployment/docsie-web -- python manage.py migrate --noinput
  helm test "${RELEASE}" --filter "name=${RELEASE}-search-test" --namespace "$NAMESPACE" --logs --timeout 3m
  log "Helm release deployed; migrations and search test completed."
}

ensure_k3s
import_images
helm_install

if [[ "${SKIP_VERIFY}" -eq 1 ]]; then
  log "Skipping verification (--skip-verify)."
else
  bash "${SCRIPT_ROOT}/verify.sh" --namespace "${NAMESPACE}" --release "${RELEASE}" --profile "${PROFILE}"
fi
log "Done."
