#!/usr/bin/env bash
# LIVE CLUSTER experiment: allowed ingress, denied ingress, DNS still works.
# Requires VPC CNI network policy enabled (Terraform sets enableNetworkPolicy=true).
set -euo pipefail

NS="${APP_NAMESPACE:-platform-demo}"
DEPLOY="${DEPLOY_NAME:-platform-demo}"

RESTRICTED_OVERRIDE='{"spec":{"securityContext":{"runAsNonRoot":true,"runAsUser":1000,"runAsGroup":1000,"seccompProfile":{"type":"RuntimeDefault"}},"containers":[{"name":"PROBE","image":"public.ecr.aws/docker/library/busybox:1.36","command":["sleep","3600"],"securityContext":{"allowPrivilegeEscalation":false,"runAsNonRoot":true,"runAsUser":1000,"capabilities":{"drop":["ALL"]},"seccompProfile":{"type":"RuntimeDefault"}}}]}}'

echo "=== Network isolation experiment ==="
echo "Confirm VPC CNI network policy:"
kubectl -n kube-system get ds aws-node -o yaml | grep -E 'enableNetworkPolicy|NETWORK_POLICY_ENFORCING_MODE' || true

cleanup() {
  kubectl -n "$NS" delete pod net-allowed net-denied --ignore-not-found >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "-- Allowed client (label access=allowed) --"
ALLOWED_JSON=${RESTRICTED_OVERRIDE//PROBE/net-allowed}
kubectl -n "$NS" delete pod net-allowed --ignore-not-found >/dev/null 2>&1 || true
kubectl -n "$NS" run net-allowed \
  --image=public.ecr.aws/docker/library/busybox:1.36 \
  --labels="access=allowed" \
  --restart=Never \
  --overrides="$ALLOWED_JSON" \
  --command -- sleep 3600
kubectl -n "$NS" wait --for=condition=Ready pod/net-allowed --timeout=120s

echo "DNS resolution:"
kubectl -n "$NS" exec net-allowed -- nslookup kubernetes.default.svc.cluster.local || \
  kubectl -n "$NS" exec net-allowed -- nslookup kubernetes

echo "HTTP to service (expect success):"
kubectl -n "$NS" exec net-allowed -- wget -qO- --timeout=5 "http://${DEPLOY}.${NS}.svc.cluster.local/healthz"
echo

echo "-- Denied client (no access=allowed label) --"
DENIED_JSON=${RESTRICTED_OVERRIDE//PROBE/net-denied}
kubectl -n "$NS" delete pod net-denied --ignore-not-found >/dev/null 2>&1 || true
kubectl -n "$NS" run net-denied \
  --image=public.ecr.aws/docker/library/busybox:1.36 \
  --restart=Never \
  --overrides="$DENIED_JSON" \
  --command -- sleep 3600
kubectl -n "$NS" wait --for=condition=Ready pod/net-denied --timeout=120s

set +e
DENY=$(kubectl -n "$NS" exec net-denied -- wget -qO- --timeout=5 "http://${DEPLOY}.${NS}.svc.cluster.local/healthz" 2>&1)
DENY_RC=$?
set -e
echo "denied client output: ${DENY}"
echo "denied client rc: ${DENY_RC}"

if [[ "$DENY_RC" -ne 0 ]]; then
  echo "RESULT: disallowed connection failed as expected"
else
  echo "RESULT: disallowed connection SUCCEEDED — NetworkPolicy may not be enforced"
  echo "Check enableNetworkPolicy on vpc-cni and that policy selects the app pods."
  exit 1
fi

echo
echo "Record allowed success + denied failure + DNS success in docs/evidence-template.md"
