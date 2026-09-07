# VPC + subnets. Default mode creates public subnets + IGW + NAT so the
# cluster can pull public container images (Docker Hub) directly. Set
# enable_public_subnets = false for a fully private VPC (no IGW, no NAT):
# then all AWS API traffic must go through VPC endpoints and images must be
# mirrored into a privately reachable registry (e.g. ECR).
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.name_prefix}-vpc"
  cidr = var.vpc_cidr

  azs              = local.azs
  public_subnets   = local.public_subnets
  private_subnets  = local.private_subnets
  database_subnets = local.database_subnets

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_nat_gateway     = var.enable_public_subnets && var.enable_nat_gateway
  single_nat_gateway     = var.single_nat_gateway
  one_nat_gateway_per_az = var.enable_public_subnets && var.enable_nat_gateway && !var.single_nat_gateway

  create_database_subnet_group       = true
  create_database_subnet_route_table = true

  enable_flow_log                                 = var.enable_vpc_flow_logs
  create_flow_log_cloudwatch_log_group            = var.enable_vpc_flow_logs
  create_flow_log_cloudwatch_iam_role             = var.enable_vpc_flow_logs
  flow_log_cloudwatch_log_group_kms_key_id        = aws_kms_key.main.arn
  flow_log_cloudwatch_log_group_retention_in_days = 365

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# S3 gateway endpoint is free and keeps bucket traffic on the AWS network.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids
}

resource "aws_security_group" "vpc_endpoints" {
  count = var.enable_interface_vpc_endpoints ? 1 : 0

  name        = "${local.name_prefix}-vpc-endpoints"
  description = "Interface VPC endpoint access from EKS nodes"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_security_group_rule" "vpc_endpoints_from_nodes" {
  count = var.enable_interface_vpc_endpoints ? 1 : 0

  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.vpc_endpoints[0].id
  source_security_group_id = module.eks.node_security_group_id
  description              = "Allow EKS nodes to reach interface VPC endpoints"
}

resource "aws_security_group_rule" "vpc_endpoints_from_ops_access" {
  count = var.enable_interface_vpc_endpoints && var.enable_ops_access_host ? 1 : 0

  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.vpc_endpoints[0].id
  source_security_group_id = aws_security_group.ops_access[0].id
  description              = "Allow private SSM access host to reach interface VPC endpoints"
}

resource "aws_security_group_rule" "vpc_endpoints_egress" {
  count = var.enable_interface_vpc_endpoints ? 1 : 0

  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.vpc_endpoints[0].id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow endpoint return traffic"
}

resource "aws_vpc_endpoint" "interface" {
  for_each = var.enable_interface_vpc_endpoints ? toset(var.interface_vpc_endpoint_services) : toset([])

  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
}
