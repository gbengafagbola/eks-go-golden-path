#!/usr/bin/env bash
# LIVE CLUSTER experiment: delete one pod and observe Deployment recovery.
# Do not treat EXAMPLE blocks as real evidence.
set -euo pipefail

NS="${APP_NAMESPACE:-platform-demo}"
DEPLOY="${DEPLOY_NAME:-platform-demo}"

echo "=== Pod recovery experiment ==="
echo "Namespace=${NS} Deployment=${DEPLOY}"
echo

echo "-- Desired replicas --"
kubectl -n "$NS" get deploy "$DEPLOY" -o wide

echo "-- Current pods --"
kubectl -n "$NS" get pods -l app.kubernetes.io/name=platform-demo -o wide

VICTIM=$(kubectl -n "$NS" get pods -l app.kubernetes.io/name=platform-demo -o jsonpath='{.items[0].metadata.name}')
echo "-- Deleting pod ${VICTIM} --"
kubectl -n "$NS" delete pod "$VICTIM" --wait=false

echo "-- Watching rollout / replica restoration (60s) --"
kubectl -n "$NS" get pods -l app.kubernetes.io/name=platform-demo -w &
WATCH_PID=$!
sleep 60
kill "$WATCH_PID" 2>/dev/null || true

echo "-- Final state --"
kubectl -n "$NS" get deploy "$DEPLOY"
kubectl -n "$NS" get pods -l app.kubernetes.io/name=platform-demo -o wide

READY=$(kubectl -n "$NS" get deploy "$DEPLOY" -o jsonpath='{.status.readyReplicas}')
DESIRED=$(kubectl -n "$NS" get deploy "$DEPLOY" -o jsonpath='{.status.replicas}')
echo "readyReplicas=${READY} replicas=${DESIRED}"
if [[ "${READY}" == "${DESIRED}" && -n "${READY}" ]]; then
  echo "RESULT: recovery observed (record this output in docs/evidence-template.md)"
else
  echo "RESULT: unexpected replica state — investigate events"
  kubectl -n "$NS" describe deploy "$DEPLOY" | tail -n 40
  exit 1
fi

cat <<'EOF'

# EXAMPLE output (not real evidence):
# pod "platform-demo-xxx" deleted
# readyReplicas=2 replicas=2
EOF
