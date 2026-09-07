# IRSA (IAM Roles for Service Accounts).
#
# Gotcha encoded from the field: the OIDC ":sub" subject for a service account
# is "system:serviceaccount:<namespace>:<name>". The workload_service_accounts
# variable uses "namespace/name" keys, converted here. Getting this conversion
# wrong yields sts:AssumeRoleWithWebIdentity AccessDenied on every pod.

data "aws_iam_policy_document" "workload_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = distinct(concat(["system:serviceaccount:${var.platform_namespace}:docsie"], [for sa, _ in var.workload_service_accounts : "system:serviceaccount:${replace(sa, "/", ":")}"]))
    }
  }
}

resource "aws_iam_role" "workload" {
  name               = "${local.name_prefix}-workload"
  assume_role_policy = data.aws_iam_policy_document.workload_assume_role.json
}

data "aws_iam_policy_document" "workload" {
  statement {
    sid = "S3ApplicationAccess"
    actions = [
      "s3:GetObject",
      "s3:GetObjectAcl",
      "s3:GetObjectTagging",
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:PutObjectTagging",
      "s3:DeleteObject",
      "s3:DeleteObjectTagging",
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = concat(
      [for bucket in aws_s3_bucket.this : bucket.arn],
      [for bucket in aws_s3_bucket.this : "${bucket.arn}/*"],
    )
  }

  statement {
    sid = "SecretsManagerRead"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = concat(
      [for secret in aws_secretsmanager_secret.app : secret.arn],
      [
        aws_secretsmanager_secret.database.arn,
        aws_secretsmanager_secret.redis.arn,
        aws_secretsmanager_secret.s3_bucket_map.arn,
      ],
    )
  }

  statement {
    sid = "KmsDecrypt"
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey",
    ]
    resources = [aws_kms_key.main.arn]
  }

  dynamic "statement" {
    for_each = var.enable_bedrock_access ? [1] : []

    content {
      sid = "BedrockInvoke"
      actions = [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream",
      ]
      resources = ["*"]
    }
  }

  statement {
    sid = "RuntimeAwsApplicationServices"
    actions = [
      "comprehend:DetectDominantLanguage",
      "comprehend:DetectEntities",
      "comprehend:DetectKeyPhrases",
      "comprehend:DetectSentiment",
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:DescribeRepositories",
      "ecr:GetAuthorizationToken",
      "ecr:GetDownloadUrlForLayer",
      "ecr:ListImages",
      "polly:DescribeVoices",
      "polly:SynthesizeSpeech",
      "ses:SendEmail",
      "ses:SendRawEmail",
      "transcribe:GetTranscriptionJob",
      "transcribe:ListTranscriptionJobs",
      "transcribe:StartTranscriptionJob",
      "translate:TranslateDocument",
      "translate:TranslateText",
    ]
    resources = ["*"]
  }

  statement {
    sid = "CloudWatchApplicationLogs"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]
    resources = [
      "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/docsie/*",
    ]
  }
}

resource "aws_iam_policy" "workload" {
  name   = "${local.name_prefix}-workload"
  policy = data.aws_iam_policy_document.workload.json
}

resource "aws_iam_role_policy_attachment" "workload" {
  role       = aws_iam_role.workload.name
  policy_arn = aws_iam_policy.workload.arn
}

data "aws_iam_policy_document" "external_secrets_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:external-secrets:external-secrets"]
    }
  }
}

resource "aws_iam_role" "external_secrets" {
  name               = "${local.name_prefix}-external-secrets"
  assume_role_policy = data.aws_iam_policy_document.external_secrets_assume_role.json
}

data "aws_iam_policy_document" "external_secrets" {
  statement {
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecrets",
    ]
    resources = concat(
      [for secret in aws_secretsmanager_secret.app : secret.arn],
      [
        aws_secretsmanager_secret.database.arn,
        aws_secretsmanager_secret.redis.arn,
        aws_secretsmanager_secret.s3_bucket_map.arn,
      ],
    )
  }

  statement {
    actions   = ["kms:Decrypt", "kms:DescribeKey"]
    resources = [aws_kms_key.main.arn]
  }
}

resource "aws_iam_policy" "external_secrets" {
  name   = "${local.name_prefix}-external-secrets"
  policy = data.aws_iam_policy_document.external_secrets.json
}

resource "aws_iam_role_policy_attachment" "external_secrets" {
  role       = aws_iam_role.external_secrets.name
  policy_arn = aws_iam_policy.external_secrets.arn
}
