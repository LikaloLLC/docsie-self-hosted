#!/usr/bin/env bash
#
# destroy-aws.sh — tear down everything created by install-aws.sh.
#
# THIS DELETES THE DATABASE, REDIS, AND (if s3_force_destroy=true) ALL S3
# CONTENT. There is no undo beyond the final RDS snapshot (if enabled).
#
# Usage:
#   ./destroy-aws.sh [--tfvars FILE] [--yes-i-know]
#
# The script requires you to type the exact deployment name prefix to confirm.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${SCRIPT_DIR}/terraform"

TFVARS_FILE=""
SKIP_PROMPT=0

log()  { printf '\033[1;34m[destroy-aws]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[destroy-aws] WARNING:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[destroy-aws] ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --tfvars)     TFVARS_FILE="$2"; shift 2 ;;
    --yes-i-know) SKIP_PROMPT=1; shift ;;
    -h|--help)    sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)            die "Unknown argument: $1" ;;
  esac
done

for tool in terraform jq; do
  command -v "$tool" >/dev/null 2>&1 || die "Missing required tool: $tool"
done

if [ -z "$TFVARS_FILE" ]; then
  [ -f "${TF_DIR}/terraform.tfvars" ] && TFVARS_FILE="${TF_DIR}/terraform.tfvars"
fi
[ -n "$TFVARS_FILE" ] && [ -f "$TFVARS_FILE" ] || die "tfvars file not found; pass --tfvars FILE."
TFVARS_FILE="$(cd "$(dirname "$TFVARS_FILE")" && pwd)/$(basename "$TFVARS_FILE")"

TF_OUT="$(terraform -chdir="$TF_DIR" output -json 2>/dev/null || echo '{}')"
NAME_PREFIX="$(echo "$TF_OUT" | jq -r '.name_prefix.value // empty')"
CLUSTER_NAME="$(echo "$TF_OUT" | jq -r '.cluster_name.value // empty')"
AWS_REGION="$(echo "$TF_OUT" | jq -r '.aws_region.value // empty')"
NAMESPACE="$(echo "$TF_OUT" | jq -r '.platform_namespace.value // empty')"
[ -n "$NAME_PREFIX" ] || die "No terraform outputs found — nothing to destroy from here (or run terraform destroy manually)."

echo
warn "You are about to DESTROY the entire '${NAME_PREFIX}' deployment in ${AWS_REGION}:"
warn "  - EKS cluster ${CLUSTER_NAME} and all workloads"
warn "  - Aurora PostgreSQL cluster (ALL application data)"
warn "  - ElastiCache Redis"
warn "  - S3 buckets (only if s3_force_destroy=true, otherwise destroy fails on non-empty buckets)"
warn "  - KMS key (30-day pending deletion), Secrets Manager secrets (30-day recovery window)"
echo

if [ "$SKIP_PROMPT" -eq 0 ]; then
  printf 'Type the deployment prefix (%s) to confirm destruction: ' "$NAME_PREFIX"
  read -r CONFIRM
  [ "$CONFIRM" = "$NAME_PREFIX" ] || die "Confirmation did not match '${NAME_PREFIX}'. Aborting."
else
  warn "--yes-i-know given; skipping typed confirmation."
fi

# --------------------------------------------------------------------------
# Pre-destroy: remove Kubernetes-created load balancers.
#
# Gotcha encoded from the field: ALBs/NLBs created by the in-cluster
# aws-load-balancer-controller are NOT in terraform state. If they are still
# attached when the VPC is destroyed, `terraform destroy` hangs and then fails
# on subnet/security-group dependencies. Delete ingresses and LoadBalancer
# services first and give AWS time to reap the load balancers.
# --------------------------------------------------------------------------
if command -v kubectl >/dev/null 2>&1 && [ -n "$CLUSTER_NAME" ]; then
  if aws eks describe-cluster --region "$AWS_REGION" --name "$CLUSTER_NAME" >/dev/null 2>&1; then
    aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME" >/dev/null 2>&1 || true
    if kubectl version >/dev/null 2>&1; then
      log "Deleting ingresses and LoadBalancer services so the ALB controller releases AWS load balancers..."
      kubectl delete ingress --all -A --timeout=120s 2>/dev/null || true
      for svc in $(kubectl get svc -A -o json 2>/dev/null \
          | jq -r '.items[] | select(.spec.type=="LoadBalancer") | "\(.metadata.namespace)/\(.metadata.name)"'); do
        kubectl -n "${svc%%/*}" delete svc "${svc##*/}" --timeout=120s 2>/dev/null || true
      done
      if [ -n "$NAMESPACE" ]; then
        log "Uninstalling helm release (best effort)..."
        helm -n "$NAMESPACE" uninstall docsie 2>/dev/null || true
      fi
      log "Waiting 90s for AWS to reap controller-created load balancers..."
      sleep 90
    else
      warn "Cluster API unreachable; skipping in-cluster cleanup. Destroy may fail on leftover load balancers — delete them in the EC2 console if so."
    fi
  fi
fi

# --------------------------------------------------------------------------
# terraform destroy
# --------------------------------------------------------------------------
warn "If the Aurora cluster has deletion_protection=true (the default), destroy will fail."
warn "In that case set deletion_protection=false (and usually skip_final_snapshot) in your tfvars, run 'terraform apply' once, then re-run this script."
log "terraform destroy..."
terraform -chdir="$TF_DIR" destroy -input=false -var-file="$TFVARS_FILE"

log "Destroy complete. Reminders:"
echo "  - Secrets Manager secrets are scheduled for deletion (30-day recovery window)."
echo "  - The KMS key is pending deletion for 30 days."
echo "  - If destroy failed on non-empty S3 buckets, either empty them or set s3_force_destroy=true and retry."
