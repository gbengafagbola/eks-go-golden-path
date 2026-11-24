# NetworkPolicy and VPC CNI enforcement

## Enabling enforcement on EKS

IAM does not control pod-to-pod traffic. Kubernetes `NetworkPolicy` objects are only effective when the cluster network plugin enforces them.

This project configures the Amazon VPC CNI add-on with:

```json
{
  "enableNetworkPolicy": "true",
  "env": {
    "NETWORK_POLICY_ENFORCING_MODE": "standard"
  }
}
```

`standard` (default): new pods may briefly default-allow until policies apply.  
`strict`: new pods default-deny until policies apply — **every** pod (including CoreDNS clients) needs required egress, including DNS.

Toggle via Terraform:

```hcl
network_policy_enforcing_mode = "strict"
```

When using `strict`, also ensure CoreDNS and system pods have working policies. Validate in a non-production account first.

## Application policy intent

The Helm `NetworkPolicy` for `platform-demo`:

- **Ingress:** only from pods with label `access=allowed` on the app port
- **Egress:** DNS to `kube-dns` in `kube-system`; optional HTTPS (443) for AWS APIs/S3
- **Not** allow-all within the namespace

Kubelet probes remain functional: VPC CNI automatically allows node IPs for health probes.

## Behavioural test

```bash
./experiments/04-network-isolation.sh
```

Success criteria:

1. Labeled client reaches `/healthz`
2. Unlabeled client fails
3. DNS resolution works

`kubectl apply` success alone is **not** evidence of enforcement.
