variable "aws_region" {
  description = "AWS region for all resources. Verify EKS version availability with: aws eks describe-cluster-versions --region <region>"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short name used for resource naming and tags"
  type        = string
  default     = "platform-demo"
}

variable "environment" {
  description = "Environment name (demo, staging, etc.)"
  type        = string
  default     = "demo"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version (must be supported in the selected region)"
  type        = string
  default     = "1.35"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.42.0.0/16"
}

variable "cluster_endpoint_public_access" {
  description = "Whether the EKS API endpoint is publicly reachable"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the public EKS API endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "node_instance_types" {
  description = "Instance types for the managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 4
}

variable "single_nat_gateway" {
  description = "Use one NAT Gateway (cheaper for demos; AZ failure affects private egress)"
  type        = bool
  default     = true
}

variable "network_policy_enforcing_mode" {
  description = "VPC CNI network policy mode: standard or strict"
  type        = string
  default     = "standard"
  validation {
    condition     = contains(["standard", "strict"], var.network_policy_enforcing_mode)
    error_message = "network_policy_enforcing_mode must be standard or strict"
  }
}

variable "app_namespace" {
  description = "Kubernetes namespace for the demo application"
  type        = string
  default     = "platform-demo"
}

variable "app_service_account" {
  description = "Kubernetes service account name for Pod Identity"
  type        = string
  default     = "platform-demo"
}

variable "github_org" {
  description = "GitHub organization or user that owns the repository"
  type        = string
  default     = "REPLACE_ME_ORG"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "REPLACE_ME_REPO"
}

variable "github_deploy_branch" {
  description = "Branch allowed to assume deploy roles via OIDC"
  type        = string
  default     = "main"
}

variable "github_oidc_use_immutable_subjects" {
  description = "If true, OIDC trust uses immutable subject format (repos created after 2026-07-15 or opted-in)"
  type        = bool
  default     = false
}

variable "github_owner_id" {
  description = "Numeric GitHub owner ID for immutable OIDC subjects (required when github_oidc_use_immutable_subjects=true)"
  type        = string
  default     = ""
}

variable "github_repo_id" {
  description = "Numeric GitHub repository ID for immutable OIDC subjects (required when github_oidc_use_immutable_subjects=true)"
  type        = string
  default     = ""
}

variable "create_github_oidc_provider" {
  description = "Create the GitHub OIDC provider. Set false and provide github_oidc_provider_arn if one already exists in the account"
  type        = bool
  default     = true
}

variable "github_oidc_provider_arn" {
  description = "Existing GitHub OIDC provider ARN when create_github_oidc_provider=false"
  type        = string
  default     = ""
}

variable "enable_cloudwatch_observability" {
  description = "Install the amazon-cloudwatch-observability EKS add-on"
  type        = bool
  default     = true
}

check "immutable_oidc_ids" {
  assert {
    condition = (
      !var.github_oidc_use_immutable_subjects ||
      (var.github_owner_id != "" && var.github_repo_id != "")
    )
    error_message = "When github_oidc_use_immutable_subjects=true, set github_owner_id and github_repo_id."
  }
}

check "existing_oidc_arn" {
  assert {
    condition = (
      var.create_github_oidc_provider ||
      var.github_oidc_provider_arn != ""
    )
    error_message = "When create_github_oidc_provider=false, set github_oidc_provider_arn."
  }
}
