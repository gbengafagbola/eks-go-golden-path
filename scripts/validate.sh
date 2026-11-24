#!/usr/bin/env bash
# Local quality gates that do NOT require AWS credentials or a live cluster.
# Exit codes: 0 = all executed local checks passed; non-zero = failure.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PASS=0
FAIL=0
SKIP=0

section() { printf '\n==> %s\n' "$1"; }

ok() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
bad() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
skip() { echo "  SKIP: $1"; SKIP=$((SKIP + 1)); }

require_cmd() {
  command -v "$1" >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
section "Go"
# ---------------------------------------------------------------------------
if require_cmd go; then
  pushd app >/dev/null
  if [ -z "$(gofmt -l .)" ]; then ok "gofmt"; else bad "gofmt (unformatted files)"; gofmt -l .; fi
  if go vet ./...; then ok "go vet"; else bad "go vet"; fi
  if go test ./... -count=1; then ok "go test"; else bad "go test"; fi
  if go build -o /tmp/platform-demo-validate ./cmd/server; then ok "go build"; else bad "go build"; fi
  popd >/dev/null
else
  bad "go not installed (required)"
fi

# ---------------------------------------------------------------------------
section "Docker image build + smoke"
# ---------------------------------------------------------------------------
if require_cmd docker; then
  if docker build -t platform-demo:validate .; then
    ok "docker build"
    docker rm -f platform-demo-validate-smoke >/dev/null 2>&1 || true
    if docker run -d --name platform-demo-validate-smoke -p 18081:8080 platform-demo:validate >/dev/null; then
      smoke_ok=0
      for _ in $(seq 1 20); do
        if curl -fsS http://127.0.0.1:18081/readyz >/dev/null 2>&1; then
          smoke_ok=1
          break
        fi
        sleep 0.5
      done
      if [ "$smoke_ok" -eq 1 ] \
        && curl -fsS http://127.0.0.1:18081/healthz >/dev/null \
        && curl -fsS http://127.0.0.1:18081/ >/dev/null \
        && curl -fsS http://127.0.0.1:18081/metrics >/dev/null \
        && curl -fsS 'http://127.0.0.1:18081/work?cpu_ms=5&duration=5ms' >/dev/null; then
        ok "docker smoke (/healthz /readyz / /metrics /work)"
      else
        bad "docker smoke"
        docker logs platform-demo-validate-smoke || true
      fi
      docker rm -f platform-demo-validate-smoke >/dev/null 2>&1 || true
    else
      bad "docker run"
    fi
  else
    bad "docker build"
  fi
else
  skip "docker not installed — image build/smoke not run"
fi

# ---------------------------------------------------------------------------
section "Helm"
# ---------------------------------------------------------------------------
if require_cmd helm; then
  if helm lint helm/platform-demo \
      --set image.repository=example.dkr.ecr.us-east-1.amazonaws.com/platform-demo \
      --set image.tag=sha-deadbeef; then ok "helm lint"; else bad "helm lint"; fi
  if helm template platform-demo helm/platform-demo \
      --namespace platform-demo \
      --set image.repository=example.dkr.ecr.us-east-1.amazonaws.com/platform-demo \
      --set image.tag=sha-deadbeef \
      --set env.DEMO_BUCKET=example-bucket \
      >/tmp/platform-demo-manifests.yaml; then
    ok "helm template"
    if grep -q 'kind: NetworkPolicy' /tmp/platform-demo-manifests.yaml; then ok "NetworkPolicy rendered"; else bad "NetworkPolicy missing"; fi
    if grep -q 'kind: HorizontalPodAutoscaler' /tmp/platform-demo-manifests.yaml; then ok "HPA rendered"; else bad "HPA missing"; fi
    if grep -q 'readOnlyRootFilesystem: true' /tmp/platform-demo-manifests.yaml; then ok "readOnlyRootFilesystem"; else bad "readOnlyRootFilesystem missing"; fi
    if grep -q 'access: allowed' /tmp/platform-demo-manifests.yaml; then ok "NetworkPolicy access=allowed"; else bad "access=allowed missing"; fi
  else
    bad "helm template"
  fi
else
  skip "helm not installed — install: https://helm.sh/docs/intro/install/"
fi

# ---------------------------------------------------------------------------
section "Terraform"
# ---------------------------------------------------------------------------
if require_cmd terraform; then
  pushd terraform >/dev/null
  if terraform fmt -check -recursive; then ok "terraform fmt"; else bad "terraform fmt"; terraform fmt -recursive -diff || true; fi
  if terraform init -backend=false -input=false; then ok "terraform init"; else bad "terraform init"; fi
  if terraform validate; then ok "terraform validate"; else bad "terraform validate"; fi
  if require_cmd tflint; then
    if tflint --init >/dev/null 2>&1 && tflint; then ok "tflint"; else bad "tflint"; fi
  else
    skip "tflint not installed (optional)"
  fi
  popd >/dev/null
else
  skip "terraform not installed — install: https://developer.hashicorp.com/terraform/install"
fi

# ---------------------------------------------------------------------------
section "Shell script lint"
# ---------------------------------------------------------------------------
if require_cmd shellcheck; then
  # shellcheck disable=SC2086
  if shellcheck -x scripts/validate.sh experiments/*.sh; then ok "shellcheck"; else bad "shellcheck"; fi
else
  skip "shellcheck not installed (optional)"
fi

# ---------------------------------------------------------------------------
section "Summary"
# ---------------------------------------------------------------------------
echo "Passed: ${PASS}  Failed: ${FAIL}  Skipped(optional/missing tool): ${SKIP}"
echo
echo "Checks requiring AWS credentials / live EKS / GitHub config:"
echo "  - terraform plan/apply"
echo "  - experiments/* against a cluster"
echo "  - GitHub Actions OIDC deploy"
echo "  - CloudWatch telemetry verification"
echo
if [ "$FAIL" -gt 0 ]; then
  echo "VALIDATION FAILED"
  exit 1
fi
echo "LOCAL VALIDATION PASSED"
exit 0
