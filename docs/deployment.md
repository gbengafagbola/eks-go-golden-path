# Deployment Guide

## Prerequisites

- AWS CLI v2 with credentials for an account that can create VPC, EKS, IAM, ECR, S3
- Terraform >= 1.5
- kubectl, Helm 3, Docker
- GitHub repository (for OIDC deploy)
- `jq` and `gh` recommended

## 1. Choose a supported EKS Kubernetes version

```bash
export AWS_REGION=us-east-1
aws eks describe-cluster-versions --region "$AWS_REGION" \
  --query 'clusterVersions[].[clusterVersion,defaultVersion,status]' \
  --output table
```

Set `kubernetes_version` in `terraform/terraform.tfvars` to a version in **standard support**.

## 2. Configure Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit github_org, github_repo, region, version, OIDC subject mode
```

### Existing GitHub OIDC provider

If `token.actions.githubusercontent.com` already exists in the account:

```hcl
create_github_oidc_provider = false
github_oidc_provider_arn    = "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
```

### Immutable OIDC subjects (repos after 2026-07-15 or opted-in)

```hcl
github_oidc_use_immutable_subjects = true
github_owner_id = "12345678"   # gh api user --jq .id  OR org id
github_repo_id  = "87654321"   # gh api repos/ORG/REPO --jq .id
```

See [oidc-github.md](./oidc-github.md).

## 2b. Private subnet / Pod Identity networking

Worker nodes run in **private** subnets. Terraform creates an **EKS Auth interface VPC endpoint** (`com.amazonaws.<region>.eks-auth`) so Pod Identity works without relying solely on NAT. Additional endpoints (STS, ECR API/DKR, S3 gateway, CloudWatch Logs) reduce NAT dependency for common paths.

## 3. Validate and apply (explicit approval required)

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan -out=tfplan
# ONLY after review / approval:
terraform apply tfplan
```

**This repository’s automated work does not run `terraform apply` for you.**

## 4. Capture outputs

```bash
terraform output
export CLUSTER=$(terraform output -raw cluster_name)
export REGION=$(terraform output -raw aws_region)
export ECR_URL=$(terraform output -raw ecr_repository_url)
export BUCKET=$(terraform output -raw demo_bucket_name)
export GITHUB_ECR_ROLE=$(terraform output -raw github_ecr_role_arn)
export GITHUB_DEPLOY_ROLE=$(terraform output -raw github_deploy_role_arn)
```

## 5. Configure kubectl

```bash
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER"
kubectl get nodes
kubectl get ns platform-demo
```

## 6. Manual Helm deploy (optional, before CI)

```bash
# Build/push once
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "${ECR_URL%%/*}"
TAG=sha-$(git rev-parse HEAD)
docker build -t "${ECR_URL}:${TAG}" .
docker push "${ECR_URL}:${TAG}"

helm upgrade --install platform-demo ../helm/platform-demo \
  --namespace platform-demo \
  --set image.repository="${ECR_URL}" \
  --set image.tag="${TAG}" \
  --set env.DEMO_BUCKET="${BUCKET}" \
  --set env.AWS_REGION="${REGION}" \
  --set env.OTEL_ENABLE_OTLP_EXPORT="true" \
  --wait
```

## 7. GitHub repository variables

In the GitHub repo → Settings → Secrets and variables → Actions → **Variables**:

| Variable | Value |
| -------- | ----- |
| `AWS_REGION` | Terraform `aws_region` |
| `EKS_CLUSTER_NAME` | `cluster_name` output |
| `ECR_REPOSITORY` | Terraform output `ecr_repository_name` (path after registry), e.g. `platform-demo-demo/platform-demo` |
| `APP_NAMESPACE` | `platform-demo` |
| `AWS_ROLE_ECR_ARN` | `github_ecr_role_arn` |
| `AWS_ROLE_DEPLOY_ARN` | `github_deploy_role_arn` |
| `DEMO_BUCKET` | `demo_bucket_name` |

No long-lived AWS access keys.

## 8. Live validation

```bash
export APP_NAMESPACE=platform-demo
export DEMO_BUCKET="$BUCKET"
export EKS_CLUSTER_NAME="$CLUSTER"
export AWS_REGION="$REGION"

./experiments/01-pod-recovery.sh
./experiments/02-rollout.sh
./experiments/03-workload-identity.sh
./experiments/04-network-isolation.sh
./experiments/05-autoscaling.sh
./experiments/06-observability.sh
```

Record results in [evidence-template.md](./evidence-template.md).

## 9. Teardown

See [cost-and-teardown.md](./cost-and-teardown.md).
