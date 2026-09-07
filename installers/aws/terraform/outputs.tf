output "name_prefix" {
  description = "Prefix used for AWS resource and secret names."
  value       = local.name_prefix
}

output "aws_region" {
  value = var.aws_region
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "platform_namespace" {
  value = var.platform_namespace
}

output "docsie_domain" {
  value = var.docsie_domain
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnet_ids" {
  value = module.vpc.private_subnets
}

output "public_subnet_ids" {
  value = module.vpc.public_subnets
}

output "s3_buckets" {
  description = "Docsie bucket names keyed by purpose."
  value       = { for key, bucket in aws_s3_bucket.this : key => bucket.bucket }
}

output "postgres_writer_endpoint" {
  value = aws_rds_cluster.postgres.endpoint
}

output "postgres_reader_endpoint" {
  value = aws_rds_cluster.postgres.reader_endpoint
}

output "postgres_database_name" {
  value = var.postgres_database_name
}

output "database_secret_name" {
  description = "Secrets Manager secret holding Postgres endpoint + credentials."
  value       = aws_secretsmanager_secret.database.name
}

output "redis_endpoint" {
  value = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "redis_secret_name" {
  description = "Secrets Manager secret holding the Redis endpoint + auth token."
  value       = aws_secretsmanager_secret.redis.name
}

output "s3_bucket_map_secret_name" {
  value = aws_secretsmanager_secret.s3_bucket_map.name
}

output "application_secret_names" {
  description = "Secrets Manager application config secrets keyed by logical name (docsie/django, docsie/email, ...)."
  value       = { for key, secret in aws_secretsmanager_secret.app : key => secret.name }
}

output "workload_irsa_role_arn" {
  description = "IRSA role assumed by the Docsie application service accounts."
  value       = aws_iam_role.workload.arn
}

output "external_secrets_role_arn" {
  value = aws_iam_role.external_secrets.arn
}

output "external_secrets_enabled" {
  value = var.enable_external_secrets
}

output "deploy_incluster_resources" {
  value = var.deploy_incluster_resources
}

output "kms_key_arn" {
  value = aws_kms_key.main.arn
}

output "ses_smtp_dns_records" {
  description = "DNS records to publish before SES can send from the configured domain."
  value = var.enable_ses_smtp ? {
    verification = {
      type  = "TXT"
      name  = "_amazonses.${var.ses_sending_domain}"
      value = aws_ses_domain_identity.smtp[0].verification_token
    }
    dkim = [
      for token in aws_ses_domain_dkim.smtp[0].dkim_tokens : {
        type  = "CNAME"
        name  = "${token}._domainkey.${var.ses_sending_domain}"
        value = "${token}.dkim.amazonses.com"
      }
    ]
  } : null
}

output "ses_smtp_user_name" {
  value = var.enable_ses_smtp ? aws_iam_user.ses_smtp[0].name : null
}

output "ops_access_instance_id" {
  value = var.enable_ops_access_host ? aws_instance.ops_access[0].id : null
}

output "ops_access_ssm_start_session_command" {
  value = var.enable_ops_access_host ? "aws ssm start-session --region ${var.aws_region} --target ${aws_instance.ops_access[0].id}" : null
}

output "ops_access_eks_port_forward_command" {
  value = var.enable_ops_access_host ? "aws ssm start-session --region ${var.aws_region} --target ${aws_instance.ops_access[0].id} --document-name AWS-StartPortForwardingSessionToRemoteHost --parameters '{\"host\":[\"${replace(module.eks.cluster_endpoint, "https://", "")}\"],\"portNumber\":[\"443\"],\"localPortNumber\":[\"9443\"]}'" : null
}

output "public_ingress" {
  value = var.enable_public_subnets
}
