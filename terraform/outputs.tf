output "aws_region" {
  value = var.aws_region
}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
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

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_arn" {
  value = module.eks.cluster_arn
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_version" {
  value = module.eks.cluster_version
}

output "oidc_provider" {
  value = module.eks.oidc_provider
}

output "oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "ecr_repository_name" {
  description = "Use this value for the GitHub Actions variable ECR_REPOSITORY"
  value       = aws_ecr_repository.app.name
}

output "ecr_repository_arn" {
  value = aws_ecr_repository.app.arn
}

output "vpc_endpoint_eks_auth_id" {
  description = "Interface endpoint required for Pod Identity from private subnets"
  value       = aws_vpc_endpoint.eks_auth.id
}

output "demo_bucket_name" {
  value = aws_s3_bucket.demo.id
}

output "demo_bucket_arn" {
  value = aws_s3_bucket.demo.arn
}

output "app_pod_identity_role_arn" {
  value = aws_iam_role.app_pod.arn
}

output "github_ecr_role_arn" {
  value = aws_iam_role.github_ecr.arn
}

output "github_deploy_role_arn" {
  value = aws_iam_role.github_deploy.arn
}

output "github_oidc_subject" {
  description = "Exact OIDC subject claim configured in IAM trust policies"
  value       = local.github_oidc_sub
}

output "app_namespace" {
  value = var.app_namespace
}

output "app_service_account" {
  value = var.app_service_account
}

output "network_policy_enforcing_mode" {
  value = var.network_policy_enforcing_mode
}

output "configure_kubectl" {
  value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}
