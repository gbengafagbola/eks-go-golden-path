data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# Look up an existing GitHub OIDC provider when we are not creating one.
data "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 0 : 1
  arn   = var.github_oidc_provider_arn
}
