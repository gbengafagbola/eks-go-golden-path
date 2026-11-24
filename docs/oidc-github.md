# GitHub Actions OIDC with AWS

## Why OIDC

GitHub Actions requests a short-lived OIDC token. IAM trusts `token.actions.githubusercontent.com` and evaluates the **audience** and **subject** before allowing `AssumeRoleWithWebIdentity`. No long-lived access keys are stored in GitHub.

## Trust policy shape (this project)

Two roles:

1. **ECR publish** — push/pull the demo repository only
2. **EKS deploy** — describe cluster + pull images; Kubernetes access via EKS access entry (namespace-scoped `AmazonEKSAdminPolicy`)

Both roles require:

```text
token.actions.githubusercontent.com:aud = sts.amazonaws.com
token.actions.githubusercontent.com:sub = <exact subject>
```

## Subject formats

### Legacy (repos created before 2026-07-15, not opted in)

```text
repo:ORG/REPO:ref:refs/heads/main
```

Terraform: `github_oidc_use_immutable_subjects = false`

### Immutable (repos created after 2026-07-15, renamed/transferred after that date, or opted in)

```text
repo:ORG@OWNER_ID/REPO@REPO_ID:ref:refs/heads/main
```

Terraform:

```hcl
github_oidc_use_immutable_subjects = true
github_owner_id = "..."
github_repo_id  = "..."
```

Discover IDs:

```bash
gh api user --jq .id
gh api orgs/ORG --jq .id
gh api repos/ORG/REPO --jq '[.owner.id, .id]'
```

If the trust policy uses the legacy form but the repository emits immutable subjects, assume-role fails with `Not authorized to perform sts:AssumeRoleWithWebIdentity`.

## Environment-based subjects

If the workflow sets `environment: NAME`, the subject becomes:

```text
repo:ORG/REPO:environment:NAME
```

(or the immutable equivalent). Update Terraform accordingly; the default workflows intentionally avoid Environments so branch subjects match.

## Existing OIDC provider

Accounts may already have the GitHub OIDC provider. Creating a duplicate fails. Set:

```hcl
create_github_oidc_provider = false
github_oidc_provider_arn    = "arn:aws:iam::ACCOUNT:oidc-provider/token.actions.githubusercontent.com"
```

## GitHub Actions variables (from Terraform outputs)

```bash
cd terraform
terraform output -raw aws_region
terraform output -raw cluster_name
terraform output -raw ecr_repository_name   # -> ECR_REPOSITORY
terraform output -raw github_ecr_role_arn   # -> AWS_ROLE_ECR_ARN
terraform output -raw github_deploy_role_arn # -> AWS_ROLE_DEPLOY_ARN
terraform output -raw demo_bucket_name      # -> DEMO_BUCKET
terraform output -raw app_namespace         # -> APP_NAMESPACE
terraform output -raw github_oidc_subject   # confirm matches trust policy
```

## Verification

After the first deploy workflow run:

1. Open the job log — confirm `configure-aws-credentials` succeeded
2. `terraform output github_oidc_subject` must match the token `sub`
3. Inspect the role trust policy in IAM
