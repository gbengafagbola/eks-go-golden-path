# Application workload identity — S3 read on the demo bucket only.
resource "aws_iam_role" "app_pod" {
  name = "${local.name_prefix}-app-pod"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEksAuthToAssumeRoleForPodIdentity"
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Condition = {
          StringEquals = {
            "aws:RequestTag/kubernetes-namespace"       = var.app_namespace
            "aws:RequestTag/kubernetes-service-account" = var.app_service_account
            "aws:RequestTag/eks-cluster-arn"            = module.eks.cluster_arn
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "app_pod_s3" {
  name = "${local.name_prefix}-app-s3-read"
  role = aws_iam_role.app_pod.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ListDemoBucket"
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.demo.arn
      },
      {
        Sid    = "ReadDemoObjects"
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.demo.arn}/*"
      }
    ]
  })
}

resource "aws_eks_pod_identity_association" "app" {
  cluster_name    = module.eks.cluster_name
  namespace       = var.app_namespace
  service_account = var.app_service_account
  role_arn        = aws_iam_role.app_pod.arn
}
