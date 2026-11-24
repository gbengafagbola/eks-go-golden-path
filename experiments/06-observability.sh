#!/usr/bin/env bash
# LIVE CLUSTER experiment: generate traffic and verify CloudWatch signals.
set -euo pipefail

NS="${APP_NAMESPACE:-platform-demo}"
DEPLOY="${DEPLOY_NAME:-platform-demo}"
CLUSTER="${EKS_CLUSTER_NAME:?Set EKS_CLUSTER_NAME}"
REGION="${AWS_REGION:-us-east-1}"

echo "=== Observability experiment ==="

echo "-- CloudWatch Observability addon --"
aws eks describe-addon \
  --cluster-name "$CLUSTER" \
  --addon-name amazon-cloudwatch-observability \
  --region "$REGION" \
  --query 'addon.{status:status,version:addonVersion}' \
  --output table

echo "-- Agent pods --"
kubectl -n amazon-cloudwatch get pods -o wide || kubectl get pods -A | grep -i cloudwatch || true

cleanup() {
  kubectl -n "$NS" delete pod traffic --ignore-not-found >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "-- Generate application traffic --"
kubectl -n "$NS" delete pod traffic --ignore-not-found >/dev/null 2>&1 || true
kubectl -n "$NS" run traffic \
  --image=public.ecr.aws/docker/library/busybox:1.36 \
  --labels="access=allowed" \
  --restart=Never \
  --overrides='{"spec":{"securityContext":{"runAsNonRoot":true,"runAsUser":1000,"runAsGroup":1000,"seccompProfile":{"type":"RuntimeDefault"}},"containers":[{"name":"traffic","image":"public.ecr.aws/docker/library/busybox:1.36","command":["/bin/sh","-c","for i in $(seq 1 50); do wget -qO- http://'"${DEPLOY}"'.'"${NS}"'.svc.cluster.local/ >/dev/null; wget -qO- http://'"${DEPLOY}"'.'"${NS}"'.svc.cluster.local/work?cpu_ms=50&duration=50ms >/dev/null; done; echo done"],"securityContext":{"allowPrivilegeEscalation":false,"runAsNonRoot":true,"runAsUser":1000,"capabilities":{"drop":["ALL"]},"seccompProfile":{"type":"RuntimeDefault"}}}]}}'
kubectl -n "$NS" wait --for=jsonpath='{.status.phase}'=Succeeded pod/traffic --timeout=180s || true

echo
echo "Verify in AWS Console / CLI (fill evidence template with REAL results):"
echo "1) Container Insights / OTel metrics for cluster ${CLUSTER}"
echo "2) Log groups under /aws/containerinsights/${CLUSTER}/ or OTel CI destinations"
echo "3) Application stdout JSON logs for platform-demo"
echo
echo "CLI examples:"
echo "  aws logs describe-log-groups --region ${REGION} --log-group-name-prefix /aws/containerinsights/${CLUSTER}"
echo "  aws logs describe-log-groups --region ${REGION} --log-group-name-prefix /aws/eks/${CLUSTER}"
echo
echo "Do NOT claim traces work unless an actual trace is visible in X-Ray / Application Signals."
echo "Application OTLP export is controlled by OTEL_ENABLE_OTLP_EXPORT (enabled in deploy workflow)."
