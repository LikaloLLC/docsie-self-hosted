# ---------------------------------------------------------------------------
# Identity / naming
# ---------------------------------------------------------------------------

variable "project" {
  description = "Short project name used in AWS resource names."
  type        = string
  default     = "docsie"
}

variable "deployment_name" {
  description = "REQUIRED. Deployment/tenant name used in AWS resource names (e.g. your company short name). Lowercase alphanumerics and hyphens only."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,20}$", var.deployment_name))
    error_message = "deployment_name must be 1-21 chars, lowercase alphanumerics and hyphens, starting with an alphanumeric."
  }
}

variable "environment" {
  description = "Deployment environment name (e.g. prod, staging, poc)."
  type        = string
  default     = "prod"
}

variable "aws_region" {
  description = "AWS region for the deployment."
  type        = string
  default     = "us-east-1"
}

variable "additional_tags" {
  description = "Additional AWS tags applied to every resource."
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# Application
# ---------------------------------------------------------------------------

variable "docsie_domain" {
  description = "REQUIRED. Public hostname the Docsie application will be served on (e.g. docs.example.com). Used for BASE_URL, ALLOWED_HOSTS, CSRF origins, and S3 CORS."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9.-]+\\.[a-z]{2,}$", var.docsie_domain))
    error_message = "docsie_domain must be a bare hostname such as docs.example.com (no scheme, no trailing slash)."
  }
}

variable "additional_cors_origins" {
  description = "Extra browser origins allowed by S3 CORS on the uploads bucket, e.g. [\"https://portal.example.com\"]."
  type        = list(string)
  default     = []
}

variable "platform_namespace" {
  description = "Kubernetes namespace the Docsie platform chart is installed into."
  type        = string
  default     = "docsie"
}

variable "additional_namespaces" {
  description = "Extra Kubernetes namespaces to pre-create (e.g. [\"dokuta\", \"elastic\"]) when deploy_incluster_resources is true."
  type        = list(string)
  default     = []
}

variable "workload_service_accounts" {
  description = "Kubernetes service accounts (\"namespace/name\" => description) trusted to assume the shared workload IRSA role. The default matches the docsie chart's service account."
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for the deployment VPC. Must not overlap networks you plan to peer/VPN with."
  type        = string
  default     = "10.100.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones to use."
  type        = number
  default     = 3
}

variable "enable_public_subnets" {
  description = "Create public subnets and an internet gateway. Set false for a fully private VPC (no IGW; you must then provide VPC endpoints and a private access path to the EKS API)."
  type        = bool
  default     = true
}

variable "enable_nat_gateway" {
  description = "Create NAT gateway(s) so private subnets have outbound internet access (needed to pull public container images). Requires enable_public_subnets = true."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use one shared NAT gateway instead of one per AZ. Cheaper; less resilient."
  type        = bool
  default     = true
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC flow logs to CloudWatch (365-day retention, KMS-encrypted). Recommended for compliance environments; adds CloudWatch cost."
  type        = bool
  default     = false
}

variable "enable_interface_vpc_endpoints" {
  description = "Create interface VPC endpoints for AWS APIs. Required for fully private (no-NAT) installs; optional cost-saving/hardening otherwise. An S3 gateway endpoint is always created."
  type        = bool
  default     = false
}

variable "interface_vpc_endpoint_services" {
  description = "AWS interface endpoint service suffixes to create when enable_interface_vpc_endpoints is true."
  type        = list(string)
  default = [
    "ecr.api",
    "ecr.dkr",
    "logs",
    "kms",
    "secretsmanager",
    "sts",
    "bedrock-runtime",
    "email-smtp",
    "monitoring",
  ]
}

# ---------------------------------------------------------------------------
# EKS
# ---------------------------------------------------------------------------

variable "kubernetes_version" {
  description = "EKS Kubernetes version."
  type        = string
  default     = "1.31"
}

variable "cluster_endpoint_public_access" {
  description = "Whether the EKS API endpoint is publicly reachable. true enables the one-step install path; set false for private-only clusters (you then need a VPN/bastion/SSM path and a two-phase apply)."
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDR blocks allowed to reach the public EKS API endpoint. STRONGLY recommended to restrict this to your office/VPN egress IPs instead of 0.0.0.0/0."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_cluster_creator_admin_permissions" {
  description = "Grant the Terraform caller Kubernetes cluster-admin. Needed for the one-step install path; prefer explicit cluster_admin_role_arns for shared/production environments."
  type        = bool
  default     = true
}

variable "cluster_admin_role_arns" {
  description = "Additional IAM role ARNs that should have Kubernetes cluster-admin access."
  type        = list(string)
  default     = []
}

variable "deploy_incluster_resources" {
  description = <<-EOT
    Two-phase deploy switch for private clusters.

    true (default, one-step installs): Terraform also creates the in-cluster
    resources — gp3 storage class, namespaces, and the aws-load-balancer-controller /
    metrics-server / external-secrets helm releases. Requires the Terraform host
    to reach the EKS API endpoint.

    false (Phase 1 of a private install): AWS infra only — VPC, EKS control plane
    and node groups, Aurora, ElastiCache, S3, IAM/IRSA, KMS, Secrets Manager. No
    kubernetes/helm provider calls are made, so the apply does not need a network
    path to a private EKS API endpoint. Re-apply with true once you have one.
  EOT
  type        = bool
  default     = true
}

variable "enable_cloudwatch_observability" {
  description = "Install the Amazon CloudWatch Observability EKS add-on (container insights). Adds CloudWatch cost."
  type        = bool
  default     = false
}

variable "enable_external_secrets" {
  description = "Install External Secrets Operator and wire it to AWS Secrets Manager via IRSA. Recommended: the installer uses it to sync the generated application secret into the cluster."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Node groups
# ---------------------------------------------------------------------------

variable "system_node_instance_types" {
  description = "Instance types for the EKS system/add-on node group."
  type        = list(string)
  default     = ["m6i.large"]
}

variable "system_node_min_size" {
  description = "Minimum EKS system nodes."
  type        = number
  default     = 2
}

variable "system_node_desired_size" {
  description = "Desired EKS system nodes."
  type        = number
  default     = 2
}

variable "system_node_max_size" {
  description = "Maximum EKS system nodes."
  type        = number
  default     = 4
}

variable "system_node_disk_size" {
  description = "Root disk size in GiB for EKS system nodes."
  type        = number
  default     = 80
}

variable "app_node_instance_types" {
  description = "Instance types for the Docsie application node group (web + celery)."
  type        = list(string)
  default     = ["m6i.xlarge"]
}

variable "app_node_min_size" {
  description = "Minimum Docsie application nodes."
  type        = number
  default     = 2
}

variable "app_node_desired_size" {
  description = "Desired Docsie application nodes."
  type        = number
  default     = 2
}

variable "app_node_max_size" {
  description = "Maximum Docsie application nodes."
  type        = number
  default     = 6
}

variable "enable_dokuta_node_group" {
  description = "Create a tainted node group for Dokuta video-processing workloads. Only needed when deploying the Dokuta charts on this cluster."
  type        = bool
  default     = false
}

variable "dokuta_node_instance_types" {
  description = "Instance types for the optional Dokuta processing node group."
  type        = list(string)
  default     = ["m6i.2xlarge"]
}

variable "dokuta_node_min_size" {
  description = "Minimum Dokuta processing nodes."
  type        = number
  default     = 1
}

variable "dokuta_node_desired_size" {
  description = "Desired Dokuta processing nodes."
  type        = number
  default     = 1
}

variable "dokuta_node_max_size" {
  description = "Maximum Dokuta processing nodes."
  type        = number
  default     = 4
}

variable "enable_search_data_node_group" {
  description = "Create a node group for in-cluster data/search services (Elasticsearch/App Search, MongoDB, ChromaDB, RabbitMQ). Only needed when deploying those charts on this cluster."
  type        = bool
  default     = false
}

variable "search_data_node_instance_types" {
  description = "Instance types for the optional search/data node group."
  type        = list(string)
  default     = ["r6i.xlarge"]
}

variable "search_data_node_min_size" {
  description = "Minimum search/data nodes."
  type        = number
  default     = 3
}

variable "search_data_node_desired_size" {
  description = "Desired search/data nodes."
  type        = number
  default     = 3
}

variable "search_data_node_max_size" {
  description = "Maximum search/data nodes."
  type        = number
  default     = 6
}

variable "search_data_node_disk_size" {
  description = "Root disk size in GiB for search/data nodes. Persistent services should still use encrypted EBS volumes via the gp3 StorageClass."
  type        = number
  default     = 200
}

variable "search_data_node_tainted" {
  description = "Taint search/data nodes so only workloads with matching tolerations schedule there."
  type        = bool
  default     = true
}

variable "enable_eks_gpu_node_group" {
  description = "Create an optional EKS GPU node group for private in-cluster model runtimes (OCR, transcription, TTS). Verify GPU quota in the target region first."
  type        = bool
  default     = false
}

variable "gpu_node_instance_types" {
  description = "GPU node instance types when enable_eks_gpu_node_group is true."
  type        = list(string)
  default     = ["g5.2xlarge"]
}

variable "gpu_node_min_size" {
  description = "Minimum GPU nodes."
  type        = number
  default     = 0
}

variable "gpu_node_desired_size" {
  description = "Desired GPU nodes."
  type        = number
  default     = 0
}

variable "gpu_node_max_size" {
  description = "Maximum GPU nodes."
  type        = number
  default     = 2
}

# ---------------------------------------------------------------------------
# Data services (Aurora PostgreSQL + ElastiCache Redis)
# ---------------------------------------------------------------------------

variable "postgres_engine_version" {
  description = "Aurora PostgreSQL engine version."
  type        = string
  default     = "16.4"
}

variable "postgres_instance_class" {
  description = "Aurora PostgreSQL instance class."
  type        = string
  default     = "db.r6g.large"
}

variable "postgres_instance_count" {
  description = "Number of Aurora PostgreSQL instances. Use 2+ for a highly available writer/reader pair."
  type        = number
  default     = 1
}

variable "postgres_database_name" {
  description = "Initial PostgreSQL database name."
  type        = string
  default     = "docsie"
}

variable "postgres_master_username" {
  description = "Aurora PostgreSQL master username."
  type        = string
  default     = "docsie_admin"
}

variable "redis_node_type" {
  description = "ElastiCache Redis node type."
  type        = string
  default     = "cache.t4g.small"
}

variable "redis_node_count" {
  description = "Number of Redis cache nodes. Use 2+ for automatic failover / multi-AZ."
  type        = number
  default     = 1
}

variable "backup_retention_days" {
  description = "Automated backup retention period for managed databases."
  type        = number
  default     = 14
}

variable "deletion_protection" {
  description = "Enable deletion protection on the Aurora cluster. Keep true outside disposable test accounts; set false before running terraform destroy."
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Skip the final RDS snapshot on destroy. Keep false outside disposable test accounts."
  type        = bool
  default     = false
}

variable "s3_force_destroy" {
  description = "Allow terraform destroy to delete non-empty S3 buckets. Keep false for real deployments."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Optional integrations
# ---------------------------------------------------------------------------

variable "enable_ses_smtp" {
  description = "Provision an SES domain identity and least-privilege SMTP credentials for Docsie transactional email. Without it, Docsie uses the console email backend (emails are logged, not sent)."
  type        = bool
  default     = false
}

variable "ses_sending_domain" {
  description = "SES sending domain used for Docsie transactional email (you must publish the verification/DKIM DNS records emitted in outputs)."
  type        = string
  default     = ""

  validation {
    condition     = !var.enable_ses_smtp || length(trimspace(var.ses_sending_domain)) > 0
    error_message = "ses_sending_domain must be set when enable_ses_smtp is true."
  }
}

variable "ses_from_email" {
  description = "From address used by Docsie transactional email."
  type        = string
  default     = ""

  validation {
    condition     = !var.enable_ses_smtp || can(regex("^[^@]+@[^@]+$", var.ses_from_email))
    error_message = "ses_from_email must be a valid address when enable_ses_smtp is true."
  }
}

variable "enable_bedrock_access" {
  description = "Grant the workload IRSA role bedrock:InvokeModel*. Note: model access must also be enabled per-model in the AWS console (Bedrock model access / Marketplace subscription), or workloads get AccessDeniedException."
  type        = bool
  default     = true
}

variable "enable_ops_access_host" {
  description = "Create a private EC2 access host reachable only through AWS Systems Manager Session Manager (no public IP, no SSH ingress). Useful for private-endpoint clusters."
  type        = bool
  default     = false
}

variable "ops_access_instance_type" {
  description = "Instance type for the private SSM access host."
  type        = string
  default     = "t3.micro"
}
