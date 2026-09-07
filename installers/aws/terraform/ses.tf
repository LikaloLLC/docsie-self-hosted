# Optional SES transactional email (enable_ses_smtp = true).
#
# Notes from the field:
#   - New SES accounts start in SANDBOX mode: they can only send to verified
#     recipients. Request SES production access before relying on user
#     invitations or password-reset delivery.
#   - You must publish the TXT/CNAME records from the ses_smtp_dns_records
#     output in your external DNS zone before SES will send from the domain.
#   - Docsie speaks SMTP (port 587 STARTTLS), which also works from fully
#     private VPCs through the `email-smtp` interface VPC endpoint.

resource "aws_ses_domain_identity" "smtp" {
  count  = var.enable_ses_smtp ? 1 : 0
  domain = var.ses_sending_domain
}

resource "aws_ses_domain_dkim" "smtp" {
  count  = var.enable_ses_smtp ? 1 : 0
  domain = aws_ses_domain_identity.smtp[0].domain
}

resource "aws_iam_user" "ses_smtp" {
  count = var.enable_ses_smtp ? 1 : 0
  name  = "${local.name_prefix}-ses-smtp"

  tags = merge(local.tags, {
    Purpose = "Docsie transactional email through SES SMTP"
  })
}

data "aws_iam_policy_document" "ses_smtp" {
  count = var.enable_ses_smtp ? 1 : 0

  statement {
    sid = "SendTransactionalEmail"
    actions = [
      "ses:SendEmail",
      "ses:SendRawEmail",
    ]
    resources = [
      "arn:aws:ses:${var.aws_region}:${data.aws_caller_identity.current.account_id}:identity/${var.ses_sending_domain}",
    ]
  }
}

resource "aws_iam_user_policy" "ses_smtp" {
  count  = var.enable_ses_smtp ? 1 : 0
  name   = "${local.name_prefix}-ses-smtp"
  user   = aws_iam_user.ses_smtp[0].name
  policy = data.aws_iam_policy_document.ses_smtp[0].json
}

resource "aws_iam_access_key" "ses_smtp" {
  count = var.enable_ses_smtp ? 1 : 0
  user  = aws_iam_user.ses_smtp[0].name
}
