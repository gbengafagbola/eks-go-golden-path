.PHONY: validate test build docker helm-lint tf-validate smoke help

ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

help:
	@echo "Targets:"
	@echo "  make validate     Run scripts/validate.sh (local gates)"
	@echo "  make test         Go tests"
	@echo "  make build        Go build"
	@echo "  make docker       Docker image build"
	@echo "  make smoke        Run container locally and hit health endpoints"
	@echo "  make helm-lint    Helm lint + template"
	@echo "  make tf-validate  Terraform fmt/init/validate"

validate:
	$(ROOT)/scripts/validate.sh

test:
	cd $(ROOT)/app && go test ./... -count=1

build:
	cd $(ROOT)/app && go build -o /tmp/platform-demo ./cmd/server

docker:
	docker build -t platform-demo:local $(ROOT)

helm-lint:
	helm lint $(ROOT)/helm/platform-demo
	helm template platform-demo $(ROOT)/helm/platform-demo \
	  --namespace platform-demo \
	  --set image.repository=example.dkr.ecr.us-east-1.amazonaws.com/platform-demo \
	  --set image.tag=sha-deadbeef \
	  --set env.DEMO_BUCKET=example-bucket >/dev/null

tf-validate:
	cd $(ROOT)/terraform && terraform fmt -check -recursive
	cd $(ROOT)/terraform && terraform init -backend=false -input=false
	cd $(ROOT)/terraform && terraform validate

smoke: docker
	@docker rm -f platform-demo-smoke >/dev/null 2>&1 || true
	docker run -d --name platform-demo-smoke -p 18080:8080 platform-demo:local
	@for i in 1 2 3 4 5 6 7 8 9 10; do \
	  if curl -fsS http://127.0.0.1:18080/readyz >/dev/null; then break; fi; \
	  sleep 1; \
	done
	curl -fsS http://127.0.0.1:18080/healthz
	@echo
	curl -fsS http://127.0.0.1:18080/readyz
	@echo
	curl -fsS http://127.0.0.1:18080/ | head -c 300
	@echo
	curl -fsS 'http://127.0.0.1:18080/work?cpu_ms=10&duration=10ms' | head -c 300
	@echo
	curl -fsS http://127.0.0.1:18080/metrics | head -n 15
	docker rm -f platform-demo-smoke >/dev/null
	@echo "SMOKE OK"
