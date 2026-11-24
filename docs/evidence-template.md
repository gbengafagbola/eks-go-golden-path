# Implementation Evidence Template

Fill this after a real AWS + GitHub run. Leave fields as `PENDING` until observed. Do not invent values.

| Field | Value |
| ----- | ----- |
| Date (UTC) | PENDING |
| Engineer | PENDING |
| AWS account ID (last 4) | PENDING |
| AWS region | PENDING |
| EKS cluster name | PENDING |
| Kubernetes version | PENDING |
| VPC CNI network policy mode | PENDING (`standard` / `strict`) |
| GitHub repository | PENDING |
| GitHub Actions CI run URL | PENDING |
| GitHub Actions deploy run URL | PENDING |
| Image tag | PENDING (`sha-<commit>`) |
| Image digest | PENDING |
| Terraform apply succeeded | PENDING |
| `go test ./...` (local) | PENDING |
| `scripts/validate.sh` (local) | PENDING |

## Pod Identity

| Check | Result |
| ----- | ------ |
| `aws sts get-caller-identity` from app SA | PENDING — paste ARN |
| Allowed `s3:ListBucket` / `GetObject` | PENDING — paste command output |
| Denied unauthorized action (e.g. CreateBucket) | PENDING — paste AccessDenied |

## NetworkPolicy

| Check | Result |
| ----- | ------ |
| VPC CNI `enableNetworkPolicy` | PENDING |
| Allowed client (`access=allowed`) HTTP | PENDING |
| Denied client (no label) HTTP | PENDING |
| DNS resolution from client | PENDING |

## Reliability

| Check | Result |
| ----- | ------ |
| Pod delete → replacement ready | PENDING |
| Rollout status / history | PENDING |
| HPA metrics available | PENDING |
| HPA replica count change under load | PENDING (or “not observed”) |

## Observability (CloudWatch)

| Check | Result |
| ----- | ------ |
| `amazon-cloudwatch-observability` addon ACTIVE | PENDING |
| Cluster/node/pod metrics visible | PENDING — console path or query |
| Application logs visible | PENDING — log group name |
| Distributed traces visible | PENDING — or “not verified / not claimed” |

## Teardown

| Check | Result |
| ----- | ------ |
| `terraform destroy` completed | PENDING |
| Residual resources checked | PENDING |
| Approximate runtime cost notes | PENDING |
