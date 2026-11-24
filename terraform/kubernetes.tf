# Bootstrap the application namespace so the GitHub deploy role can remain
# namespace-scoped (it cannot create namespaces with AmazonEKSAdminPolicy alone).
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      module.eks.cluster_name,
      "--region",
      var.aws_region,
    ]
  }
}

resource "kubernetes_namespace_v1" "app" {
  metadata {
    name = var.app_namespace
    labels = {
      "app.kubernetes.io/name"             = "platform-demo"
      "app.kubernetes.io/part-of"          = "eks-go-golden-path"
      "pod-security.kubernetes.io/enforce" = "restricted"
      "pod-security.kubernetes.io/audit"   = "restricted"
      "pod-security.kubernetes.io/warn"    = "restricted"
      "kubernetes.io/metadata.name"        = var.app_namespace
    }
  }

  depends_on = [module.eks]
}
