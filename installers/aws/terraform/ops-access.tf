# Optional private EC2 access host (enable_ops_access_host = true), reachable
# only through AWS Systems Manager Session Manager. No public IP, no SSH
# ingress. Intended for private-endpoint clusters: use the
# ops_access_eks_port_forward_command output to tunnel kubectl to the EKS API.

data "aws_iam_policy_document" "ops_access_assume_role" {
  count = var.enable_ops_access_host ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_ami" "al2023" {
  count = var.enable_ops_access_host ? 1 : 0

  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_iam_role" "ops_access" {
  count = var.enable_ops_access_host ? 1 : 0

  name               = "${local.name_prefix}-ops-access"
  assume_role_policy = data.aws_iam_policy_document.ops_access_assume_role[0].json
}

resource "aws_iam_role_policy_attachment" "ops_access_ssm" {
  count = var.enable_ops_access_host ? 1 : 0

  role       = aws_iam_role.ops_access[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ops_access" {
  count = var.enable_ops_access_host ? 1 : 0

  name = "${local.name_prefix}-ops-access"
  role = aws_iam_role.ops_access[0].name
}

resource "aws_security_group" "ops_access" {
  count = var.enable_ops_access_host ? 1 : 0

  name        = "${local.name_prefix}-ops-access"
  description = "Private SSM access host for EKS administration"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_security_group_rule" "ops_access_egress_https" {
  count = var.enable_ops_access_host ? 1 : 0

  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.ops_access[0].id
  cidr_blocks       = [var.vpc_cidr]
  description       = "Allow private HTTPS to EKS and VPC interface endpoints"
}

resource "aws_security_group_rule" "eks_api_from_ops_access" {
  count = var.enable_ops_access_host ? 1 : 0

  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = module.eks.cluster_security_group_id
  source_security_group_id = aws_security_group.ops_access[0].id
  description              = "Allow private SSM access host to reach the EKS API"
}

resource "aws_instance" "ops_access" {
  count = var.enable_ops_access_host ? 1 : 0

  ami                         = data.aws_ami.al2023[0].id
  instance_type               = var.ops_access_instance_type
  subnet_id                   = module.vpc.private_subnets[0]
  vpc_security_group_ids      = [aws_security_group.ops_access[0].id]
  iam_instance_profile        = aws_iam_instance_profile.ops_access[0].name
  associate_public_ip_address = false

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted   = true
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name = "${local.name_prefix}-ops-access"
  }

  depends_on = [
    aws_iam_role_policy_attachment.ops_access_ssm,
  ]
}
