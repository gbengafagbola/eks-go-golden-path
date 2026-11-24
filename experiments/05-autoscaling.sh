#!/usr/bin/env bash
# LIVE CLUSTER experiment: generate bounded /work load and observe HPA.
set -euo pipefail

NS="${APP_NAMESPACE:-platform-demo}"
DEPLOY="${DEPLOY_NAME:-platform-demo}"

echo "=== Autoscaling experiment ==="
echo "-- Metrics API --"
kubectl get --raw "/apis/metrics.k8s.io/v1beta1/namespaces/${NS}/pods" | head -c 2000 || {
  echo "metrics-server not responding — HPA cannot scale on CPU"
  exit 1
}
echo

kubectl -n "$NS" get hpa
kubectl -n "$NS" get deploy "$DEPLOY"

cleanup() {
  kubectl -n "$NS" delete pod loadgen --ignore-not-found >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "-- Starting load generator (bounded /work) for ~5 minutes --"
kubectl -n "$NS" delete pod loadgen --ignore-not-found >/dev/null 2>&1 || true
kubectl -n "$NS" run loadgen \
  --image=public.ecr.aws/docker/library/busybox:1.36 \
  --labels="access=allowed" \
  --restart=Never \
  --overrides='{"spec":{"securityContext":{"runAsNonRoot":true,"runAsUser":1000,"runAsGroup":1000,"seccompProfile":{"type":"RuntimeDefault"}},"containers":[{"name":"loadgen","image":"public.ecr.aws/docker/library/busybox:1.36","command":["/bin/sh","-c","while true; do wget -qO- http://'"${DEPLOY}"'.'"${NS}"'.svc.cluster.local/work?cpu_ms=400&duration=100ms >/dev/null; done"],"securityContext":{"allowPrivilegeEscalation":false,"runAsNonRoot":true,"runAsUser":1000,"capabilities":{"drop":["ALL"]},"seccompProfile":{"type":"RuntimeDefault"}}}]}}'

echo "Watch HPA (recording window ~300s). Record replica changes if observed."
kubectl -n "$NS" get hpa "$DEPLOY" --watch &
WATCH=$!
sleep 300
kill "$WATCH" 2>/dev/null || true

echo
kubectl -n "$NS" get hpa "$DEPLOY"
kubectl -n "$NS" get deploy "$DEPLOY"
kubectl -n "$NS" top pods -l app.kubernetes.io/name=platform-demo || true

echo
echo "NOTE: If replicas did not change, record actual metrics/HPA status."
echo "Do not claim autoscaling works without observed replica changes."
