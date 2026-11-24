# Local validation results

**Date:** 2026-11-23  
**Command:** `./scripts/validate.sh`  
**Result:** `LOCAL VALIDATION PASSED` (exit 0)

## Authoritative check count

The validation script increments `PASS` once per `ok()` call in [`scripts/validate.sh`](../scripts/validate.sh).

**Final totals: 15 PASS · 0 FAIL · 2 SKIP (optional tools)**

Earlier mentions of “13 checks” referred to an intermediate run before the Docker smoke check and Helm manifest asserts were counted separately. **Use 15 as the authoritative local-gate count.**

## Every check and result

| # | Check (exact `ok()` label / meaning) | Result |
| - | ------------------------------------ | ------ |
| 1 | `gofmt` | PASS |
| 2 | `go vet` | PASS |
| 3 | `go test` (`go test ./... -count=1` — config, handlers, middleware, telemetry) | PASS |
| 4 | `go build` | PASS |
| 5 | `docker build` | PASS |
| 6 | `docker smoke (/healthz /readyz / /metrics /work)` | PASS |
| 7 | `helm lint` | PASS |
| 8 | `helm template` | PASS |
| 9 | `NetworkPolicy rendered` | PASS |
| 10 | `HPA rendered` | PASS |
| 11 | `readOnlyRootFilesystem` | PASS |
| 12 | `NetworkPolicy access=allowed` | PASS |
| 13 | `terraform fmt` | PASS |
| 14 | `terraform init` (`-backend=false`) | PASS |
| 15 | `terraform validate` | PASS (upstream VPC module deprecated `aws_region.name` warning only) |

## Optional skips (not failures)

| Check | Result |
| ----- | ------ |
| `tflint` | SKIP — not installed |
| `shellcheck` | SKIP — not installed |

## Not run (require AWS / GitHub / live cluster)

- `terraform plan` / `terraform apply`
- GitHub Actions OIDC assume-role
- Experiments `01`–`06`
- CloudWatch metric/log/trace presence

## Notes

- Docker smoke confirms the distroless image serves health, metrics, and bounded work endpoints.
- Terraform providers locked in `terraform/.terraform.lock.hcl` (AWS provider v6.73.0, EKS module v21.30.2, VPC module v5.21.0).
- Helm requires `image.repository` / `image.tag` at install time (`required()` guards).
- VPC endpoints for `eks-auth`, STS, ECR, S3, and Logs are present in Terraform config for private-subnet Pod Identity and reduced NAT dependency; **endpoint creation has not been applied**.
