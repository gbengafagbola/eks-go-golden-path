# Observability

## Pipeline

```text
Go app (JSON logs + OTel metrics/traces)
  ├─ stdout/stderr → node/agent log collection → CloudWatch Logs
  ├─ /metrics (Prometheus) scrape path via OTel/agents when configured
  └─ OTLP HTTP → CloudWatch agent (when OTEL_ENABLE_OTLP_EXPORT=true)
       └─ amazon-cloudwatch-observability EKS add-on
            └─ CloudWatch metrics (OTel Container Insights) + optional X-Ray/Application Signals
```

## Cluster telemetry

Terraform installs `amazon-cloudwatch-observability` with:

- `otelContainerInsights.enabled = true` (recommended)
- `containerInsights.enabled = false` (classic off to reduce demo cost)

Agent IAM uses a **dedicated IRSA role** (`CloudWatchAgentServerPolicy` + `AWSXrayWriteOnlyAccess`), not the application Pod Identity role.

## Application signals

| Signal | Implementation | Verification |
| ------ | -------------- | ------------ |
| Metrics | OTel → Prometheus registry on `/metrics`; optional OTLP export | Scrape `/metrics`; CloudWatch after OTLP enabled |
| Logs | Structured JSON to stdout | CloudWatch log groups for the cluster/namespace |
| Traces | OTel SDK + OTLP when export enabled | Only claim if a trace appears in X-Ray / Application Signals |

High-cardinality labels (raw request IDs) are **not** used on metrics. Request IDs appear in logs only.

## How to verify

```bash
export EKS_CLUSTER_NAME=...
export AWS_REGION=us-east-1
./experiments/06-observability.sh

aws logs describe-log-groups --region "$AWS_REGION" \
  --log-group-name-prefix "/aws/containerinsights/${EKS_CLUSTER_NAME}"
```

Console: CloudWatch → Container Insights / Application Signals for the cluster.

## Cost notes

Telemetry ingestion, log retention, and metric cardinality drive ongoing cost. Prefer OTel CI alone for demos; shorten retention; tear down when finished.
