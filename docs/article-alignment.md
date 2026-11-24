# Article alignment matrix

Maps claims from *Building a Secure, Observable Golden Path for Go Microservices on Amazon EKS* to implementation status.

| Claim | Implementation support | Still needs live AWS evidence |
| ----- | ---------------------- | ----------------------------- |
| Terraform VPC + EKS + managed nodes | `terraform/` modules and resources | `terraform apply` success, cluster version |
| Configurable region / Kubernetes version | variables + docs | Version available in chosen region |
| GitHub OIDC, no long-lived keys | `oidc_github.tf` + deploy workflow | Successful Actions assume-role |
| Separate deploy vs workload identity | GHA roles ≠ app Pod Identity role | Both exercised independently |
| EKS Pod Identity least privilege (S3) | `pod_identity.tf` + experiment 03 | Caller identity + AccessDenied |
| Private-subnet Pod Identity networking | `vpc_endpoints.tf` (eks-auth + STS/ECR/S3/logs) | Endpoint exists; identity experiment succeeds |
| VPC CNI NetworkPolicy enabled | vpc-cni configuration_values | Experiment 04 allow/deny |
| Helm probes, PDB, HPA, security context | `helm/platform-demo` | Rollout healthy; HPA metrics/replicas |
| CloudWatch Observability / OTel CI | add-on + IRSA + docs | Metrics/logs visible in CloudWatch |
| CloudWatch IRSA least privilege | Namespace-scoped `amazon-cloudwatch:*` today (not exact SA list) | Prefer explicit SA subjects before claiming least privilege for agents |
| Application metrics `/metrics` + OTel | Go telemetry package | Live scrape + optional OTLP path |
| Distributed tracing | OTel SDK + optional OTLP | **Only if** trace seen in destination |
| CI fails on test/build/lint | `.github/workflows/ci.yml` | Green/red Actions run URL |
| Immutable image tags | `sha-<gitsha>` | Digest from deploy log |
| Failure experiments documented | `experiments/` | Recorded outputs in evidence template |
| Cost + teardown guidance | `docs/cost-and-teardown.md` | Actual destroy confirmation |

## Explicitly out of scope (article §8)

Certificate/secret lifecycle, image signing provenance beyond scan step, admission policies (OPA/Kyverno), multi-env promotion, DR, formal SLOs — documented as limitations, not claimed complete.
