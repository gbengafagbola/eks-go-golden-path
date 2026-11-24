# Dedicated IRSA role for CloudWatch Observability agents (not the application workload).
data "aws_iam_policy_document" "cloudwatch_observability_assume" {
  count = var.enable_cloudwatch_observability ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Cover agent / fluent-bit / controller SAs created by the add-on.
    condition {
      test     = "StringLike"
      variable = "${module.eks.oidc_provider}:sub"
      values = [
        "system:serviceaccount:amazon-cloudwatch:*",
      ]
    }
  }
}

resource "aws_iam_role" "cloudwatch_observability" {
  count = var.enable_cloudwatch_observability ? 1 : 0

  name               = "${local.name_prefix}-cw-obs"
  assume_role_policy = data.aws_iam_policy_document.cloudwatch_observability_assume[0].json
}

resource "aws_iam_role_policy_attachment" "cloudwatch_observability" {
  count = var.enable_cloudwatch_observability ? 1 : 0

  role       = aws_iam_role.cloudwatch_observability[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_observability_xray" {
  count = var.enable_cloudwatch_observability ? 1 : 0

  role       = aws_iam_role.cloudwatch_observability[0].name
  policy_arn = "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess"
}
