locals {
  name_prefix  = lower("${var.project}-${var.deployment_name}-${var.environment}")
  cluster_name = "${local.name_prefix}-eks"
  azs          = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # Subnet plan (indexes are stable so adding/removing public subnets does not
  # renumber private/database subnets):
  #   public   -> cidrsubnet(vpc_cidr, 4, 0..az_count-1)   (only when enabled)
  #   private  -> cidrsubnet(vpc_cidr, 4, 4..)
  #   database -> cidrsubnet(vpc_cidr, 4, 8..)
  # When enable_public_subnets = false the VPC module creates no internet
  # gateway (it only does so when public_subnets is non-empty), yielding a
  # fully private VPC.
  public_subnets   = var.enable_public_subnets ? [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, i)] : []
  private_subnets  = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, i + 4)]
  database_subnets = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, i + 8)]

  docsie_base_url = "https://${var.docsie_domain}"

  tags = merge(
    {
      Project     = var.project
      Deployment  = var.deployment_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Application = "docsie-platform"
    },
    var.additional_tags,
  )

  # The Docsie bucket set. Bucket names are suffixed with the AWS account id
  # for global uniqueness.
  bucket_purposes = {
    app_storage = {
      suffix      = "app-storage"
      description = "Docsie published documentation static assets and application files"
    }
    uploads = {
      suffix      = "uploads"
      description = "User-uploaded media, OCR input, and video/document processing input"
    }
    feedback = {
      suffix      = "feedback"
      description = "Feedback and product telemetry files"
    }
    portal = {
      suffix      = "portal"
      description = "Static portal output"
    }
    logs_archive = {
      suffix      = "logs-archive"
      description = "Long-term application access and audit log archive"
    }
  }

  namespaces = distinct(concat(
    [var.platform_namespace],
    var.enable_external_secrets ? ["external-secrets"] : [],
    var.additional_namespaces,
  ))

  ebs_csi_node_policy = {
    AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  }
}
