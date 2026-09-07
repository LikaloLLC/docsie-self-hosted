#!/usr/bin/env bash
# docsie-platform uninstaller.
#
# By default this removes the Helm release but PRESERVES:
#   - the generated credential secrets (helm.sh/resource-policy: keep)
#   - all PersistentVolumeClaims (customer data)
# Pass --purge-data to delete PVCs and secrets too (irreversible).
set -euo pipefail

NAMESPACE="${DOCSIE_NAMESPACE:-docsie}"
RELEASE="${DOCSIE_RELEASE:-docsie-platform}"
PURGE_DATA=0
DELETE_NAMESPACE=0
ASSUME_YES=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace) NAMESPACE="${2:?}"; shift 2 ;;
    --release) RELEASE="${2:?}"; shift 2 ;;
    --purge-data) PURGE_DATA=1; shift ;;
    --delete-namespace) DELETE_NAMESPACE=1; shift ;;
    --yes) ASSUME_YES=1; shift ;;
    -h|--help)
      echo "Usage: uninstall.sh [--namespace ns] [--release name] [--purge-data] [--delete-namespace] [--yes]"
      exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

log() { printf '[uninstall] %s\n' "$*"; }

command -v helm >/dev/null 2>&1 || { echo "[uninstall] helm is required." >&2; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "[uninstall] kubectl is required." >&2; exit 1; }

if [[ "${PURGE_DATA}" -eq 1 && "${ASSUME_YES}" -ne 1 ]]; then
  printf '[uninstall] --purge-data will DELETE ALL DATA (databases, object storage, indexes) in %s. Type "purge" to continue: ' "${NAMESPACE}"
  read -r answer
  [[ "${answer}" == "purge" ]] || { log "Aborted."; exit 1; }
fi

if helm -n "${NAMESPACE}" status "${RELEASE}" >/dev/null 2>&1; then
  log "Uninstalling Helm release ${NAMESPACE}/${RELEASE}..."
  helm -n "${NAMESPACE}" uninstall "${RELEASE}" --wait --timeout 10m
else
  log "Helm release ${NAMESPACE}/${RELEASE} not found; continuing with cleanup."
fi

if [[ "${PURGE_DATA}" -eq 1 ]]; then
  log "Purging PVCs..."
  kubectl -n "${NAMESPACE}" delete pvc --all --ignore-not-found
  log "Purging generated secrets..."
  kubectl -n "${NAMESPACE}" delete secret docsie-platform-secrets docsie-platform-derived --ignore-not-found
else
  log "PVCs and generated secrets preserved (use --purge-data to remove)."
fi

if [[ "${DELETE_NAMESPACE}" -eq 1 ]]; then
  log "Deleting namespace ${NAMESPACE}..."
  kubectl delete namespace "${NAMESPACE}" --ignore-not-found
fi

log "Done."
