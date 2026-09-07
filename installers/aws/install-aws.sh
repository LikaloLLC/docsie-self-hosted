#!/usr/bin/env bash
#
# install-aws.sh — one-step Docsie platform install on AWS.
#
#   1. Checks prerequisites (aws, terraform, kubectl, helm, jq).
#   2. terraform init/apply (VPC, EKS, Aurora, ElastiCache, S3, KMS, IRSA,
#      Secrets Manager, cluster add-ons).
#   3. Waits for the cluster and writes kubeconfig.
#   4. Creates the platform namespace and (optionally) the Docker Hub image
#      pull secret.
#   5. Syncs the generated application secrets from AWS Secrets Manager into
#      the cluster via External Secrets Operator.
#   6. Renders helm values from terraform outputs and installs the Docsie
#      platform chart in managed-services mode (in-cluster Postgres/Redis/
#      MinIO disabled — Aurora/ElastiCache/S3 are used directly).
#   7. Optionally runs Django migrations.
#
# Usage:
#   ./install-aws.sh [--tfvars FILE] [--yes] [--skip-terraform] [--no-helm]
#                    [--no-migrate] [--chart REF] [--chart-version X.Y.Z]
#                    [--extra-values FILE]
#
# Environment:
#   DOCKERHUB_USERNAME / DOCKERHUB_TOKEN  Create the image pull secret for
#                                         private Docsie images (recommended).
#   DOCSIE_SUBCHART_KEY                   If the platform chart nests the app
#                                         values under a subchart key, set it
#                                         here (e.g. "docsie") to nest the
#                                         generated app values accordingly.
set -euo pipefail
umask 077

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${SCRIPT_DIR}/terraform"
GEN_DIR="${SCRIPT_DIR}/generated"

TFVARS_FILE=""
AUTO_APPROVE=0
PREFLIGHT_ONLY=0
SKIP_TERRAFORM=0
DO_HELM=1
DO_MIGRATE=1
CHART_REF="${SCRIPT_DIR}/../../charts/docsie-platform"
CHART_VERSION="0.2.0-preview.1"
CERTIFICATE_ARN="${DOCSIE_ACM_CERTIFICATE_ARN:-}"
EXTRA_VALUES=""
RELEASE_NAME="docsie"
PULL_SECRET_NAME="docker-hub-repository-secret"

log()  { printf '\033[1;34m[install-aws]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[install-aws] WARNING:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[install-aws] ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

usage() { sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0; }

while [ $# -gt 0 ]; do
  case "$1" in
    --tfvars)         TFVARS_FILE="$2"; shift 2 ;;
    --preflight-only) PREFLIGHT_ONLY=1; shift ;;
    --yes|-y)         AUTO_APPROVE=1; shift ;;
    --skip-terraform) SKIP_TERRAFORM=1; shift ;;
    --no-helm)        DO_HELM=0; shift ;;
    --no-migrate)     DO_MIGRATE=0; shift ;;
    --certificate-arn) CERTIFICATE_ARN="$2"; shift 2 ;;
    --chart)          CHART_REF="$2"; shift 2 ;;
    --chart-version)  CHART_VERSION="$2"; shift 2 ;;
    --extra-values)   EXTRA_VALUES="$2"; shift 2 ;;
    --release)        RELEASE_NAME="$2"; shift 2 ;;
    -h|--help)        usage ;;
    *)                die "Unknown argument: $1 (see --help)" ;;
  esac
done

# --------------------------------------------------------------------------
# 1. Prerequisites
# --------------------------------------------------------------------------
if [ -d "$CHART_REF" ]; then
  helm dependency build "$CHART_REF" >/dev/null
fi
log "Checking prerequisites..."
MISSING=""
for tool in aws terraform kubectl helm jq python3 docker; do
  command -v "$tool" >/dev/null 2>&1 || MISSING="${MISSING} ${tool}"
done
[ -z "$MISSING" ] || die "Missing required tools:${MISSING}. Install them and re-run."

# Registry access and architecture must be proven BEFORE terraform apply.
if [ -n "${DOCKERHUB_USERNAME:-}" ] && [ -n "${DOCKERHUB_TOKEN:-}" ]; then
  printf '%s' "$DOCKERHUB_TOKEN" | docker login --username "$DOCKERHUB_USERNAME" --password-stdin >/dev/null
fi
PREFLIGHT_ARGS=("$CHART_REF" --values "${SCRIPT_DIR}/../../examples/aws-managed.yaml")
[ -n "$EXTRA_VALUES" ] && PREFLIGHT_ARGS+=(--values "$EXTRA_VALUES")
python3 "${SCRIPT_DIR}/../../scripts/check-images.py" "${PREFLIGHT_ARGS[@]}"
if [ "$PREFLIGHT_ONLY" -eq 1 ]; then
  log "Image preflight passed. No AWS resources were created."
  exit 0
fi

aws sts get-caller-identity >/dev/null 2>&1 \
  || die "AWS credentials not configured (aws sts get-caller-identity failed). Set AWS_PROFILE or credentials first."
log "AWS identity: $(aws sts get-caller-identity --query Arn --output text)"

if [ -n "$TFVARS_FILE" ]; then
  [ -f "$TFVARS_FILE" ] || die "tfvars file not found: $TFVARS_FILE"
  TFVARS_FILE="$(cd "$(dirname "$TFVARS_FILE")" && pwd)/$(basename "$TFVARS_FILE")"
elif [ -f "${TF_DIR}/terraform.tfvars" ]; then
  TFVARS_FILE="${TF_DIR}/terraform.tfvars"
else
  die "No tfvars found. Copy terraform/terraform.tfvars.example to terraform/terraform.tfvars, edit it, and re-run (or pass --tfvars FILE)."
fi
log "Using variables: ${TFVARS_FILE}"

# --------------------------------------------------------------------------
# 2. Terraform
# --------------------------------------------------------------------------
if [ "$SKIP_TERRAFORM" -eq 0 ]; then
  log "terraform init..."
  terraform -chdir="$TF_DIR" init -input=false

  APPLY_ARGS=(-input=false -var-file="$TFVARS_FILE")
  if [ "$AUTO_APPROVE" -eq 1 ]; then
    APPLY_ARGS+=(-auto-approve)
  else
    warn "Terraform will show a plan and prompt for approval. This CREATES BILLABLE AWS RESOURCES (EKS, Aurora, ElastiCache, NAT, ...) — roughly \$700+/month at default sizing."
  fi
  log "terraform apply..."
  terraform -chdir="$TF_DIR" apply "${APPLY_ARGS[@]}"
else
  log "Skipping terraform apply (--skip-terraform); using existing state/outputs."
fi

log "Reading terraform outputs..."
TF_OUT="$(terraform -chdir="$TF_DIR" output -json)"
tfout() { echo "$TF_OUT" | jq -r "$1"; }

NAME_PREFIX="$(tfout '.name_prefix.value')"
AWS_REGION="$(tfout '.aws_region.value')"
CLUSTER_NAME="$(tfout '.cluster_name.value')"
NAMESPACE="$(tfout '.platform_namespace.value')"
DOCSIE_DOMAIN="$(tfout '.docsie_domain.value')"
WORKLOAD_ROLE_ARN="$(tfout '.workload_irsa_role_arn.value')"
ESO_ENABLED="$(tfout '.external_secrets_enabled.value')"
INCLUSTER="$(tfout '.deploy_incluster_resources.value')"
POSTGRES_ENDPOINT="$(tfout '.postgres_writer_endpoint.value')"
REDIS_ENDPOINT="$(tfout '.redis_endpoint.value')"

[ -n "$CLUSTER_NAME" ] && [ "$CLUSTER_NAME" != "null" ] || die "terraform outputs are empty — did the apply succeed?"

if [ "$INCLUSTER" != "true" ]; then
  warn "deploy_incluster_resources is false (private Phase 1). Storage class, namespaces, and cluster add-ons are NOT installed yet."
  warn "Once you have a network path to the private EKS endpoint, set deploy_incluster_resources = true, re-run this script, and it will complete the install."
fi

# --------------------------------------------------------------------------
# 3. Cluster access
# --------------------------------------------------------------------------
log "Waiting for EKS cluster ${CLUSTER_NAME} to be active..."
aws eks wait cluster-active --region "$AWS_REGION" --name "$CLUSTER_NAME"

log "Writing kubeconfig..."
mkdir -p "$GEN_DIR"
export KUBECONFIG="${GEN_DIR}/kubeconfig"
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME" --kubeconfig "$KUBECONFIG" >/dev/null

if [ "$INCLUSTER" != "true" ]; then
  log "Phase 1 complete. Infra is up; skipping in-cluster steps."
  exit 0
fi

kubectl version >/dev/null 2>&1 \
  || die "kubectl cannot reach the cluster API. If this is a private-endpoint cluster, start your VPN/SSM tunnel first (see terraform output ops_access_eks_port_forward_command)."

log "Waiting for at least one Ready node (up to 15 min)..."
DEADLINE=$(( $(date +%s) + 900 ))
until kubectl get nodes --no-headers 2>/dev/null | awk '$2 == "Ready"' | grep -q .; do
  [ "$(date +%s)" -lt "$DEADLINE" ] || die "No Ready nodes after 15 minutes; check the EKS node groups in the AWS console."
  sleep 15
done
kubectl get nodes

# --------------------------------------------------------------------------
# 4. Namespace + image pull secret
# --------------------------------------------------------------------------
log "Ensuring namespace ${NAMESPACE}..."
kubectl get namespace "$NAMESPACE" >/dev/null 2>&1 || kubectl create namespace "$NAMESPACE"

HAVE_PULL_SECRET=0
if [ -n "${DOCKERHUB_USERNAME:-}" ] && [ -n "${DOCKERHUB_TOKEN:-}" ]; then
  log "Creating/updating image pull secret ${PULL_SECRET_NAME}..."
  kubectl -n "$NAMESPACE" create secret docker-registry "$PULL_SECRET_NAME" \
    --docker-server=https://index.docker.io/v1/ \
    --docker-username="$DOCKERHUB_USERNAME" \
    --docker-password="$DOCKERHUB_TOKEN" \
    --dry-run=client -o yaml | kubectl apply -f -
  HAVE_PULL_SECRET=1
elif kubectl -n "$NAMESPACE" get secret "$PULL_SECRET_NAME" >/dev/null 2>&1; then
  HAVE_PULL_SECRET=1
else
  warn "DOCKERHUB_USERNAME/DOCKERHUB_TOKEN not set and no ${PULL_SECRET_NAME} secret exists. Private Docsie images will fail to pull until you create it."
fi

# --------------------------------------------------------------------------
# 5. Secrets sync (AWS Secrets Manager -> docsie-secret via ESO)
# --------------------------------------------------------------------------
if [ "$ESO_ENABLED" = "true" ]; then
  log "Waiting for External Secrets Operator CRDs..."
  DEADLINE=$(( $(date +%s) + 300 ))
  until kubectl get crd externalsecrets.external-secrets.io >/dev/null 2>&1; do
    [ "$(date +%s)" -lt "$DEADLINE" ] || die "External Secrets CRDs not available after 5 minutes."
    sleep 10
  done
  kubectl -n external-secrets rollout status deploy -l app.kubernetes.io/name=external-secrets --timeout=300s || true

  log "Applying ClusterSecretStore + ExternalSecret (target secret: docsie-secret)..."
  kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1
kind: ClusterSecretStore
metadata:
  name: aws-secrets-manager
spec:
  provider:
    aws:
      service: SecretsManager
      region: ${AWS_REGION}
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: docsie-env
  namespace: ${NAMESPACE}
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: docsie-secret
    creationPolicy: Owner
  dataFrom:
    - extract:
        key: ${NAME_PREFIX}/docsie/django
    - extract:
        key: ${NAME_PREFIX}/docsie/email
    - extract:
        key: ${NAME_PREFIX}/docsie/oauth
    - extract:
        key: ${NAME_PREFIX}/docsie/storage
    - extract:
        key: ${NAME_PREFIX}/docsie/datastores
EOF

  log "Waiting for docsie-secret to sync..."
  DEADLINE=$(( $(date +%s) + 300 ))
  until kubectl -n "$NAMESPACE" get secret docsie-secret >/dev/null 2>&1; do
    if [ "$(date +%s)" -ge "$DEADLINE" ]; then
      kubectl -n "$NAMESPACE" describe externalsecret docsie-env || true
      die "docsie-secret did not sync within 5 minutes. Check the ExternalSecret status above (usually IRSA trust or secret-name mismatch)."
    fi
    sleep 10
  done
  log "docsie-secret synced."
else
  warn "External Secrets is disabled; you must create the ${NAMESPACE}/docsie-secret Kubernetes secret yourself from the Secrets Manager values before pods can start."
fi

# --------------------------------------------------------------------------
# 6. Render values + helm install
# --------------------------------------------------------------------------
mkdir -p "$GEN_DIR"
VALUES_FILE="${GEN_DIR}/values-${NAME_PREFIX}.yaml"

RENDER_ARGS=()
[ "$HAVE_PULL_SECRET" -eq 1 ] && RENDER_ARGS+=(--pull-secret "$PULL_SECRET_NAME")
[ -n "$CERTIFICATE_ARN" ] && RENDER_ARGS+=(--certificate-arn "$CERTIFICATE_ARN")
printf '%s' "$TF_OUT" | python3 "${SCRIPT_DIR}/render-values.py" "${RENDER_ARGS[@]}" > "$VALUES_FILE"
log "Rendered helm values: ${VALUES_FILE}"

if [ "$DO_HELM" -eq 0 ]; then
  log "--no-helm given; stopping after values render."
  exit 0
fi

HELM_ARGS=(upgrade --install "$RELEASE_NAME" "$CHART_REF" -n "$NAMESPACE" -f "$VALUES_FILE" --wait --timeout 15m)
[ -n "$CHART_VERSION" ] && HELM_ARGS+=(--version "$CHART_VERSION")
[ -n "$EXTRA_VALUES" ]  && HELM_ARGS+=(-f "$EXTRA_VALUES")

bash "${SCRIPT_DIR}/../../scripts/ensure-search-operator.sh" "$KUBECONFIG"

log "Installing Docsie platform chart: ${CHART_REF} ${CHART_VERSION:+(version ${CHART_VERSION})}"
helm "${HELM_ARGS[@]}"

# --------------------------------------------------------------------------
# 7. Migrations
# --------------------------------------------------------------------------
if [ "$DO_MIGRATE" -eq 1 ]; then
  WEB_DEPLOY="$(kubectl -n "$NAMESPACE" get deploy -o name 2>/dev/null | grep -m1 'web' || true)"
  if [ -n "$WEB_DEPLOY" ]; then
    log "Running Django migrations in ${WEB_DEPLOY}..."
    kubectl -n "$NAMESPACE" rollout status "$WEB_DEPLOY" --timeout=600s
    if ! kubectl -n "$NAMESPACE" exec "deploy/${WEB_DEPLOY#deployment.apps/}" -- python manage.py migrate --noinput; then
      die "Migrations failed. The installation is incomplete; inspect the web deployment logs."
    fi
  else
    die "No web deployment found; the installation is incomplete."
  fi
fi

# --------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------
bash "${SCRIPT_DIR}/../bundle/verify.sh" --namespace "$NAMESPACE" --release "$RELEASE_NAME" --profile kb --storage managed
log "Infrastructure and workload checks complete; verify the browser workflows in docs/ACCEPTANCE.md."
echo
echo "  Cluster:      ${CLUSTER_NAME} (${AWS_REGION})"
echo "  Namespace:    ${NAMESPACE}"
echo "  App domain:   ${DOCSIE_DOMAIN}"
echo "  Postgres:     ${POSTGRES_ENDPOINT}"
echo "  Redis:        ${REDIS_ENDPOINT} (TLS)"
echo "  Values file:  ${VALUES_FILE}"
echo
echo "Next steps:"
echo "  1. Point DNS: CNAME ${DOCSIE_DOMAIN} -> \$(kubectl -n ${NAMESPACE} get ingress -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')"
echo "  2. TLS: attach an ACM certificate to the ALB ingress (see README, 'TLS')."
echo "  3. If using SES: publish the DNS records from 'terraform output ses_smtp_dns_records' and request SES production access."
echo "  4. Fill OAuth/SSO credentials in Secrets Manager secret '${NAME_PREFIX}/docsie/oauth', then restart deployments."
