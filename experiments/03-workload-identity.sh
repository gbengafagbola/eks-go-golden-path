#!/usr/bin/env bash
# LIVE CLUSTER experiment: verify Pod Identity caller identity, allowed S3 read, denied action.
set -euo pipefail

NS="${APP_NAMESPACE:-platform-demo}"
SA="${APP_SERVICE_ACCOUNT:-platform-demo}"
BUCKET="${DEMO_BUCKET:?Set DEMO_BUCKET to the Terraform output demo_bucket_name}"
REGION="${AWS_REGION:-us-east-1}"

echo "=== Workload identity experiment ==="
echo "NS=${NS} SA=${SA} BUCKET=${BUCKET} REGION=${REGION}"

cleanup() {
  kubectl -n "$NS" delete pod identity-probe --ignore-not-found >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "Launching ephemeral debug pod with app service account (restricted PSS compatible)..."
kubectl -n "$NS" delete pod identity-probe --ignore-not-found >/dev/null 2>&1 || true
kubectl -n "$NS" run identity-probe \
  --image=public.ecr.aws/aws-cli/aws-cli:2.22.12 \
  --restart=Never \
  --overrides="$(cat <<JSON
{
  "spec": {
    "serviceAccountName": "${SA}",
    "securityContext": {
      "runAsNonRoot": true,
      "runAsUser": 1000,
      "runAsGroup": 1000,
      "seccompProfile": { "type": "RuntimeDefault" }
    },
    "containers": [{
      "name": "aws-cli",
      "image": "public.ecr.aws/aws-cli/aws-cli:2.22.12",
      "command": ["sleep", "3600"],
      "securityContext": {
        "allowPrivilegeEscalation": false,
        "runAsNonRoot": true,
        "runAsUser": 1000,
        "capabilities": { "drop": ["ALL"] },
        "seccompProfile": { "type": "RuntimeDefault" }
      }
    }]
  }
}
JSON
)"
kubectl -n "$NS" wait --for=condition=Ready pod/identity-probe --timeout=180s
POD=identity-probe

echo
echo "-- 1) Caller identity (expect app Pod Identity role ARN) --"
kubectl -n "$NS" exec "$POD" -- aws sts get-caller-identity

echo
echo "-- 2) Allowed: ListBucket / GetObject on demo bucket --"
kubectl -n "$NS" exec "$POD" -- aws s3 ls "s3://${BUCKET}/" --region "$REGION"
kubectl -n "$NS" exec "$POD" -- aws s3 cp "s3://${BUCKET}/golden-path/README.txt" - --region "$REGION"

echo
echo "-- 3) Denied: attempt CreateBucket (expect AccessDenied) --"
set +e
DENY_OUT=$(kubectl -n "$NS" exec "$POD" -- aws s3 mb "s3://${BUCKET}-should-fail-$(date +%s)" --region "$REGION" 2>&1)
DENY_RC=$?
set -e
echo "$DENY_OUT"
if echo "$DENY_OUT" | grep -qiE 'AccessDenied|not authorized|Access Denied'; then
  echo "RESULT: negative permission test observed AccessDenied (record output)"
else
  echo "RESULT: unexpected — did not observe AccessDenied (rc=${DENY_RC})"
  exit 1
fi

cat <<'EOF'

# EXAMPLE (not evidence):
# Arn: arn:aws:sts::123456789012:assumed-role/platform-demo-demo-app-pod/...
# AccessDenied when calling CreateBucket
EOF
