module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = "${local.name_prefix}-eks"
  kubernetes_version = var.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  endpoint_public_access                   = var.cluster_endpoint_public_access
  endpoint_public_access_cidrs             = var.cluster_endpoint_public_access_cidrs
  endpoint_private_access                  = true
  enable_cluster_creator_admin_permissions = true

  addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent          = true
      before_compute       = true
      configuration_values = local.vpc_cni_configuration
    }
    eks-pod-identity-agent = {
      most_recent = true
    }
    metrics-server = {
      most_recent = true
    }
  }

  eks_managed_node_groups = {
    default = {
      name           = "${local.name_prefix}-ng"
      instance_types = var.node_instance_types
      ami_type       = "AL2023_x86_64_STANDARD"

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      subnet_ids = module.vpc.private_subnets

      labels = {
        workload = "general"
      }
    }
  }

  # Namespace-scoped admin for the deploy role (not account-wide IAM admin).
  access_entries = {
    github_deploy = {
      principal_arn = aws_iam_role.github_deploy.arn
      type          = "STANDARD"

      policy_associations = {
        namespace_admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
          access_scope = {
            type       = "namespace"
            namespaces = [var.app_namespace]
          }
        }
      }
    }
  }

  tags = local.common_tags
}

# CloudWatch Observability is managed separately to avoid IRSA ↔ addon cycles.
data "aws_eks_addon_version" "cloudwatch_observability" {
  count = var.enable_cloudwatch_observability ? 1 : 0

  addon_name         = "amazon-cloudwatch-observability"
  kubernetes_version = var.kubernetes_version
  most_recent        = true
}

resource "aws_eks_addon" "cloudwatch_observability" {
  count = var.enable_cloudwatch_observability ? 1 : 0

  cluster_name                = module.eks.cluster_name
  addon_name                  = "amazon-cloudwatch-observability"
  addon_version               = data.aws_eks_addon_version.cloudwatch_observability[0].version
  service_account_role_arn    = aws_iam_role.cloudwatch_observability[0].arn
  configuration_values        = local.cloudwatch_observability_configuration
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    module.eks,
    aws_iam_role_policy_attachment.cloudwatch_observability,
  ]
}
