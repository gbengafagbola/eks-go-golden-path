#!/usr/bin/env bash
# LIVE CLUSTER experiment: inspect rollout status and document rollback.
set -euo pipefail

NS="${APP_NAMESPACE:-platform-demo}"
DEPLOY="${DEPLOY_NAME:-platform-demo}"

echo "=== Rollout behaviour experiment ==="
kubectl -n "$NS" rollout status "deploy/${DEPLOY}" --timeout=5m
kubectl -n "$NS" rollout history "deploy/${DEPLOY}"
kubectl -n "$NS" get rs -l app.kubernetes.io/name=platform-demo

echo
echo "To roll back after a bad release:"
echo "  kubectl -n ${NS} rollout undo deploy/${DEPLOY}"
echo "  kubectl -n ${NS} rollout status deploy/${DEPLOY}"

echo
echo "Service reachability (port-forward):"
kubectl -n "$NS" port-forward "svc/${DEPLOY}" 18080:80 >/tmp/rollout-pf.log 2>&1 &
PF=$!
trap 'kill $PF 2>/dev/null || true' EXIT
sleep 2
curl -fsS http://127.0.0.1:18080/healthz
echo
curl -fsS http://127.0.0.1:18080/readyz
echo
echo "RESULT: record rollout history and health responses as evidence"
