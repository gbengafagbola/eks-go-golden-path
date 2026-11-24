# Final deliverables report

## 1. Audit of the original project

The workspace was **empty**. No prior Terraform, Go app, Helm chart, workflows, or docs existed. Full greenfield implementation. See [audit.md](./audit.md).

## 2. Files created (summary)

| Area | Paths |
| ---- | ----- |
| App | `app/cmd/server`, `app/internal/{config,handlers,middleware,telemetry}`, `app/go.mod`, `app/go.sum` |
| Image | `Dockerfile`, `.dockerignore` |
| Terraform | `terraform/*.tf`, `terraform.tfvars.example`, `.terraform.lock.hcl` |
| Helm | `helm/platform-demo/**` |
| CI/CD | `.github/workflows/ci.yml`, `deploy.yml` |
| Scripts | `scripts/validate.sh`, `experiments/01`–`06` |
| Docs | `README.md`, `docs/*` |

## 3. Architecture diagram

See Mermaid diagram in [README.md](../README.md).

## 4. Local validation commands and results

```bash
./scripts/validate.sh
```

**Actual result:** `LOCAL VALIDATION PASSED` — 15 passed, 0 failed (includes container smoke test). Details in [validation-results.md](./validation-results.md).

## 5. Failures addressed during implementation

| Failure | Fix |
| ------- | --- |
| OTel Prometheus exporter no longer implements `http.Handler` | Use custom registry + `promhttp.HandlerFor` |
| Docker `# syntax=docker/dockerfile:1.7` lease error | Removed BuildKit syntax directive / cache mounts |
| `terraform fmt` drift | Ran `terraform fmt -recursive` |
| NetworkPolicy allowed entire namespace (broke deny test) | Ingress only from `access=allowed` |
| CW Observability IRSA ↔ EKS addon cycle | Separate `aws_eks_addon` after cluster + OIDC |
| Private-subnet Pod Identity needs EKS Auth API | Interface VPC endpoint `eks-auth` (+ STS/ECR/S3/logs) |
| Deploy could push without tests | Deploy workflow `needs: test` pre-check job |
| Image digest via `docker inspect` flaky after push | `aws ecr describe-images` for digest |

## 6. Exact AWS deployment commands (do not run without approval)

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# edit github_org/repo, region, kubernetes version, OIDC mode
terraform init
terraform plan -out=tfplan
terraform apply tfplan   # EXPLICIT APPROVAL REQUIRED

aws eks update-kubeconfig --region "$(terraform output -raw aws_region)" \
  --name "$(terraform output -raw cluster_name)"
```

Full guide: [deployment.md](./deployment.md).

## 7. Exact GitHub configuration steps

1. Push repo to GitHub  
2. Apply Terraform with correct `github_*` variables (immutable subjects if applicable)  
3. Set Actions variables: `AWS_REGION`, `EKS_CLUSTER_NAME`, `ECR_REPOSITORY`, `APP_NAMESPACE`, `AWS_ROLE_ECR_ARN`, `AWS_ROLE_DEPLOY_ARN`, `DEMO_BUCKET`  
4. Merge to `main` to trigger deploy workflow  
5. See [oidc-github.md](./oidc-github.md)

## 8. Live-cluster validation commands

```bash
export APP_NAMESPACE=platform-demo
export DEMO_BUCKET=$(terraform -chdir=terraform output -raw demo_bucket_name)
export EKS_CLUSTER_NAME=$(terraform -chdir=terraform output -raw cluster_name)
export AWS_REGION=$(terraform -chdir=terraform output -raw aws_region)

./experiments/01-pod-recovery.sh
./experiments/02-rollout.sh
./experiments/03-workload-identity.sh
./experiments/04-network-isolation.sh
./experiments/05-autoscaling.sh
./experiments/06-observability.sh
```

Fill [evidence-template.md](./evidence-template.md) with real outputs only.

## 9. Cost and teardown

See [cost-and-teardown.md](./cost-and-teardown.md). Dominant costs: EKS control plane, node EC2, NAT Gateway, CloudWatch ingestion.

```bash
helm uninstall platform-demo -n platform-demo || true
cd terraform && terraform destroy
```

## 10. Article claims supported by implementation evidence (local)

- Go service with health/ready/metrics/bounded work, tests, structured logs, OTel instrumentation  
- Multi-stage non-root container builds locally  
- Terraform config for VPC, EKS, add-ons, OIDC roles, Pod Identity, ECR, S3 validates  
- Helm chart renders NetworkPolicy, HPA, PDB, restricted security contexts  
- CI/CD workflows defined with SHA-pinned actions and OIDC deploy path  
- Experiment scripts and evidence template ready  

## 11. Claims that still require live AWS validation

- Successful `terraform apply` / cluster creation  
- GitHub OIDC assume-role and deploy run  
- Pod Identity caller identity + AccessDenied  
- NetworkPolicy allow/deny behavioural proof  
- Pod recovery / rollout on a real cluster  
- HPA replica change under load  
- CloudWatch metrics/logs (and traces only if observed)  

## 12. Known limitations

- HTTPS egress in NetworkPolicy is port 443 (not prefix-listed to AWS)  
- Namespace-scoped deploy role cannot create namespaces (Terraform creates `platform-demo`)  
- `strict` CNI mode needs extra system policies — default is `standard`  
- Tracing must not be claimed until visible in CloudWatch/X-Ray  
- Not a complete production platform (secrets, admission, DR, multi-env omitted by design)  
