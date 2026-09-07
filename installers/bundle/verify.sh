#!/usr/bin/env bash
# docsie-platform runtime verification (design doc §3.5, runtime tier).
#   - all Deployments/StatefulSets of the release are ready
#   - the Django migrations job (if any) completed
#   - model endpoint answers a canary prompt (degrades gracefully offline)
# Static BOM/SHA256 verification is the bundle builder's verify step (Phase 2).
set -euo pipefail

NAMESPACE="${DOCSIE_NAMESPACE:-docsie}"
RELEASE="${DOCSIE_RELEASE:-docsie-platform}"
PROFILE="kb"
STORAGE="local"
TIMEOUT="${DOCSIE_VERIFY_TIMEOUT:-300}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace) NAMESPACE="${2:?}"; shift 2 ;;
    --release) RELEASE="${2:?}"; shift 2 ;;
    --storage) STORAGE="${2:?}"; shift 2 ;;
    --profile) PROFILE="${2:?}"; shift 2 ;;
    --timeout) TIMEOUT="${2:?}"; shift 2 ;;
    -h|--help)
      echo "Usage: verify.sh [--namespace ns] [--release name] [--profile kb|kb-ai|full] [--timeout seconds]"
      exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

log()  { printf '[verify] %s\n' "$*"; }
warn() { printf '[verify] WARN: %s\n' "$*" >&2; }

FAILURES=0
failure() { printf '[verify] FAIL: %s\n' "$*" >&2; FAILURES=$((FAILURES + 1)); }

command -v kubectl >/dev/null 2>&1 || { echo "[verify] kubectl is required." >&2; exit 1; }
kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1 || { echo "[verify] Namespace ${NAMESPACE} not found." >&2; exit 1; }

# ------------------------------------------------------ workloads ready
log "Checking Deployments in ${NAMESPACE}..."
deployments="$(kubectl -n "${NAMESPACE}" get deployments -l "app.kubernetes.io/instance=${RELEASE}" -o name 2>/dev/null || true)"
if [[ -z "${deployments}" ]]; then
  failure "No Deployments found in ${NAMESPACE} — is the release installed?"
else
  while IFS= read -r deploy; do
    [[ -n "${deploy}" ]] || continue
    if kubectl -n "${NAMESPACE}" rollout status "${deploy}" --timeout="${TIMEOUT}s" >/dev/null 2>&1; then
      log "  ready: ${deploy}"
    else
      failure "not ready after ${TIMEOUT}s: ${deploy}"
    fi
  done <<< "${deployments}"
fi

log "Checking StatefulSets in ${NAMESPACE}..."
statefulsets="$(kubectl -n "${NAMESPACE}" get statefulsets -o name 2>/dev/null || true)"
while IFS= read -r sts; do
  [[ -n "${sts}" ]] || continue
  if kubectl -n "${NAMESPACE}" rollout status "${sts}" --timeout="${TIMEOUT}s" >/dev/null 2>&1; then
    log "  ready: ${sts}"
  else
    failure "not ready after ${TIMEOUT}s: ${sts}"
  fi
done <<< "${statefulsets}"

# ------------------------------------------------------ migrations job
log "Checking migration job..."
migrate_jobs="$(kubectl -n "${NAMESPACE}" get jobs -o name 2>/dev/null | grep -Ei 'migrat' || true)"
if [[ -z "${migrate_jobs}" ]]; then
  if ! kubectl -n "${NAMESPACE}" exec deployment/docsie-web -- python manage.py migrate --check --noinput >/dev/null 2>&1; then
    failure "Django has unapplied migrations or the database is unreachable."
  fi
else
  while IFS= read -r job; do
    [[ -n "${job}" ]] || continue
    if kubectl -n "${NAMESPACE}" wait --for=condition=complete "${job}" --timeout="${TIMEOUT}s" >/dev/null 2>&1; then
      log "  complete: ${job}"
    else
      failure "migration job did not complete: ${job}"
    fi
  done <<< "${migrate_jobs}"
fi

# ------------------------------------------------------ generated secrets
log "Checking platform secrets..."
SECRETS="docsie-platform-secrets docsie-platform-derived"
[ "$STORAGE" = "managed" ] && SECRETS="docsie-secret"
for secret in $SECRETS; do
  if kubectl -n "${NAMESPACE}" get secret "${secret}" >/dev/null 2>&1; then
    log "  present: ${secret}"
  else
    failure "missing secret: ${secret}"
  fi
done

# ------------------------------------------------------ model endpoint canary
model_endpoint="${DOCSIE_MODEL_ENDPOINT:-}"
if [[ -z "${model_endpoint}" ]] && command -v helm >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
  model_endpoint="$(helm -n "${NAMESPACE}" get values "${RELEASE}" --all -o json 2>/dev/null | python3 -c '
import json, sys
try:
    v = json.load(sys.stdin)
    print((v.get("global") or {}).get("modelEndpoint") or "")
except Exception:
    print("")' || true)"
fi

if [[ -z "${model_endpoint}" ]]; then
  if [[ "$PROFILE" != "kb" ]]; then failure "AI profile requires global.modelEndpoint."; fi
elif ! command -v curl >/dev/null 2>&1; then
  failure "curl is required to verify the configured model endpoint."
else
  log "Canary prompt against ${model_endpoint}..."
  canary_payload='{"model":"default","messages":[{"role":"user","content":"Reply with the single word: ok"}],"max_tokens":8}'
  if response="$(curl -fsS --max-time 30 -H 'Content-Type: application/json' \
        -d "${canary_payload}" "${model_endpoint%/}/chat/completions" 2>&1)"; then
    if printf '%s' "${response}" | grep -q '"choices"'; then
      log "  model endpoint answered the canary prompt."
    else
      failure "Model endpoint did not return a completion."
    fi
  else
    failure "Model endpoint is unreachable."
  fi
fi

if [[ "${FAILURES}" -gt 0 ]]; then
  printf '[verify] %d check(s) FAILED.\n' "${FAILURES}" >&2
  exit 1
fi
log "All checks passed (profile: ${PROFILE})."
