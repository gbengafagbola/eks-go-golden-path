locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    GoldenPath  = "eks-go-microservice"
  }

  github_repo_path = "${var.github_org}/${var.github_repo}"

  # Legacy: repo:ORG/REPO:ref:refs/heads/BRANCH
  # Immutable (post-2026-07-15 / opted-in): repo:ORG@OWNER_ID/REPO@REPO_ID:ref:refs/heads/BRANCH
  github_oidc_sub = var.github_oidc_use_immutable_subjects ? (
    "repo:${var.github_org}@${var.github_owner_id}/${var.github_repo}@${var.github_repo_id}:ref:refs/heads/${var.github_deploy_branch}"
    ) : (
    "repo:${local.github_repo_path}:ref:refs/heads/${var.github_deploy_branch}"
  )

  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  vpc_cni_configuration = jsonencode({
    enableNetworkPolicy = "true"
    env = {
      NETWORK_POLICY_ENFORCING_MODE = var.network_policy_enforcing_mode
    }
  })

  # OTel Container Insights recommended; classic CI disabled to control demo cost.
  cloudwatch_observability_configuration = jsonencode({
    containerInsights = {
      enabled = false
    }
    otelContainerInsights = {
      enabled = true
    }
  })
}
