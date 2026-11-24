# Cost considerations and teardown

## What incurs cost while running

| Resource | Notes |
| -------- | ----- |
| EKS control plane | Hourly per cluster |
| Managed node group | EC2 for `t3.medium` × desired count |
| NAT Gateway | Hourly + data processing (often a large demo cost) |
| Elastic IPs | Associated with NAT |
| ECR storage | Small for demos |
| S3 | Negligible for the marker object |
| CloudWatch | Metrics, logs, and (if enabled) traces ingestion + retention |
| Public IPv4 (if charged in region) | Check current AWS pricing |

Defaults use **one NAT Gateway** (`single_nat_gateway=true`) to reduce cost at the expense of AZ resilience for egress.

## Estimate before apply

Use the AWS Pricing Calculator or:

```bash
# After apply, list billable resources
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Project,Values=platform-demo \
  --region "$AWS_REGION"
```

## Teardown

```bash
# 1) Remove the Helm release (optional but avoids orphan finalizers)
helm uninstall platform-demo -n platform-demo || true

# 2) Destroy infrastructure
cd terraform
terraform destroy
```

If destroy fails on ENIs/load balancers:

```bash
kubectl get svc,ingress -A
# Delete leftover LoadBalancer Services, wait for ENI cleanup, re-run destroy
```

Confirm:

```bash
aws eks list-clusters --region "$AWS_REGION"
aws ec2 describe-nat-gateways --filter Name=tag:Project,Values=platform-demo \
  --query 'NatGateways[?State!=`deleted`]'
```

Record teardown confirmation in the evidence template.
