# AWS installer preview

The script creates EKS, Aurora PostgreSQL, ElastiCache Redis, S3, KMS, IAM,
Secrets Manager and cluster add-ons, then installs the platform chart in managed
storage mode. This preview has not passed clean-account acceptance yet.

## Prerequisites

AWS CLI, Terraform >=1.6, kubectl, Helm, Python 3 and Docker Buildx. Configure
AWS credentials for an account you control. Obtain private image access from
Docsie and log into Docker Hub, or set DOCKERHUB_USERNAME / DOCKERHUB_TOKEN.
Use a hostname you control and an ACM certificate in the deployment region.

```bash
bash installers/aws/install-aws.sh --preflight-only
cp installers/aws/terraform/terraform.tfvars.example installers/aws/terraform/terraform.tfvars
# Edit the file: deployment_name, docsie_domain, aws_region and operator IP allowlist.
bash installers/aws/install-aws.sh --certificate-arn "$DOCSIE_ACM_CERTIFICATE_ARN"
```

Image checks run before Terraform creates resources. Missing images or missing
registry access stop the install. Terraform shows a plan and prompts unless
`--yes` is supplied. EKS, database, cache and networking charges are your
responsibility even during a free trial.

Options: `--preflight-only`, `--tfvars FILE`, `--yes`, `--skip-terraform`,
`--no-helm`, `--no-migrate`, `--chart REF`, `--chart-version VERSION`,
`--extra-values FILE`, `--certificate-arn ARN`, `--release NAME`.
Custom image replacements can be supplied through --extra-values and are checked
by preflight. The default application chart version is pinned in the distribution.

Terraform state contains generated secrets. Keep state secure, use an appropriate
remote backend for shared operation, and never commit state, generated values,
credentials or kubeconfig. The script writes its kubeconfig to
`installers/aws/generated/kubeconfig`, leaving your default kubeconfig alone.

After installation, configure DNS to the ALB, confirm HTTPS, configure email and
customer AI access, then execute ../../docs/ACCEPTANCE.md. Without an ACM
certificate the generated ingress uses HTTP; this is only for a disposable
connectivity test, not production use. Storage is S3 via IRSA; no generated
MinIO credentials should reach AWS workloads.

Private-only networking requires two phases: deploy_incluster_resources=false
for infrastructure, then true once the operator has private EKS network access.
Use private image mirrors and internal ingress. Preflight must run on a host
that can access those mirrors. Extra full-profile services require additional
configuration and are not claimed ready by this installer.

Teardown: review `destroy-aws.sh`. Aurora deletion protection, snapshots and
retained secrets may intentionally keep resources. Never run it against an
installation whose data you intend to retain without a backup/recovery plan.
