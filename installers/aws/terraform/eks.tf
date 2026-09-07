# EKS cluster with managed node groups. In-cluster Kubernetes resources
# (storage class + namespaces) are gated behind var.deploy_incluster_resources
# so private-only installs can run a two-phase apply (see variables.tf).
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.cluster_name
  cluster_version = var.kubernetes_version

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs = (
    var.cluster_endpoint_public_access ? var.cluster_endpoint_public_access_cidrs : []
  )

  enable_irsa                              = true
  enable_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_addons = merge(
    {
      coredns = {
        most_recent = true
      }
      kube-proxy = {
        most_recent = true
      }
      vpc-cni = {
        most_recent = true
      }
      aws-ebs-csi-driver = {
        most_recent = true
      }
    },
    var.enable_cloudwatch_observability ? {
      amazon-cloudwatch-observability = {
        most_recent = true
        configuration_values = jsonencode({
          manager = {
            applicationSignals = {
              autoMonitor = {
                monitorAllServices = false
              }
            }
          }
        })
      }
    } : {},
  )

  eks_managed_node_groups = merge(
    {
      system = {
        name                         = "${local.name_prefix}-system"
        iam_role_use_name_prefix     = false
        iam_role_name                = "${local.name_prefix}-system-ng"
        iam_role_additional_policies = local.ebs_csi_node_policy
        instance_types               = var.system_node_instance_types
        min_size                     = var.system_node_min_size
        max_size                     = var.system_node_max_size
        desired_size                 = var.system_node_desired_size
        disk_size                    = var.system_node_disk_size
        labels = {
          workload = "system"
        }
      }

      app = {
        name                         = "${local.name_prefix}-app"
        iam_role_use_name_prefix     = false
        iam_role_name                = "${local.name_prefix}-app-ng"
        iam_role_additional_policies = local.ebs_csi_node_policy
        instance_types               = var.app_node_instance_types
        min_size                     = var.app_node_min_size
        max_size                     = var.app_node_max_size
        desired_size                 = var.app_node_desired_size
        disk_size                    = 120
        labels = {
          workload  = "docsie-core"
          nodegroup = "app"
        }
      }
    },
    var.enable_dokuta_node_group ? {
      dokuta = {
        name                         = "${local.name_prefix}-dokuta"
        iam_role_use_name_prefix     = false
        iam_role_name                = "${local.name_prefix}-dokuta-ng"
        iam_role_additional_policies = local.ebs_csi_node_policy
        instance_types               = var.dokuta_node_instance_types
        min_size                     = var.dokuta_node_min_size
        max_size                     = var.dokuta_node_max_size
        desired_size                 = var.dokuta_node_desired_size
        disk_size                    = 160
        labels = {
          workload  = "dokuta-processing"
          nodegroup = "dokuta"
        }
        taints = {
          dokuta = {
            key    = "workload"
            value  = "dokuta"
            effect = "NO_SCHEDULE"
          }
        }
      }
    } : {},
    var.enable_search_data_node_group ? {
      search_data = {
        name                         = "${local.name_prefix}-search-data"
        iam_role_use_name_prefix     = false
        iam_role_name                = "${local.name_prefix}-search-ng"
        iam_role_additional_policies = local.ebs_csi_node_policy
        instance_types               = var.search_data_node_instance_types
        min_size                     = var.search_data_node_min_size
        max_size                     = var.search_data_node_max_size
        desired_size                 = var.search_data_node_desired_size
        disk_size                    = var.search_data_node_disk_size
        labels = {
          workload  = "search-data"
          nodegroup = "search-data"
        }
        taints = var.search_data_node_tainted ? {
          search_data = {
            key    = "workload"
            value  = "search-data"
            effect = "NO_SCHEDULE"
          }
        } : {}
      }
    } : {},
    var.enable_eks_gpu_node_group ? {
      gpu = {
        name                         = "${local.name_prefix}-gpu"
        iam_role_use_name_prefix     = false
        iam_role_name                = "${local.name_prefix}-gpu-ng"
        iam_role_additional_policies = local.ebs_csi_node_policy
        ami_type                     = "AL2_x86_64_GPU"
        instance_types               = var.gpu_node_instance_types
        min_size                     = var.gpu_node_min_size
        max_size                     = var.gpu_node_max_size
        desired_size                 = var.gpu_node_desired_size
        disk_size                    = 200
        labels = {
          workload  = "model-runtime"
          nodegroup = "gpu"
        }
        taints = {
          gpu = {
            key    = "nvidia.com/gpu"
            value  = "true"
            effect = "NO_SCHEDULE"
          }
        }
      }
    } : {},
  )

  access_entries = {
    for arn in var.cluster_admin_role_arns : replace(arn, "/[:/]/", "_") => {
      principal_arn = arn
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  node_security_group_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = null
  }
}

resource "kubernetes_storage_class" "gp3" {
  count = var.deploy_incluster_resources ? 1 : 0

  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type      = "gp3"
    fsType    = "ext4"
    encrypted = "true"
    kmsKeyId  = aws_kms_key.main.arn
  }

  depends_on = [module.eks]
}

resource "kubernetes_namespace" "core" {
  for_each = var.deploy_incluster_resources ? toset(local.namespaces) : toset([])

  metadata {
    name = each.key
  }

  depends_on = [module.eks]
}
