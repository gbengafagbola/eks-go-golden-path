From infrastructure provisioning to workload identity, network isolation, continuous delivery, and operational visibility — and why “it deployed” is not the same as “it’s ready.”

Hey guys!

Thanks for joining. Today we’re going to talk about something that quietly burns engineering teams: a Kubernetes deployment that looks successful… and still leaves you with an operational mess.

The pods are green. The service responds. Someone drops a “shipped” in Slack. Then Monday morning arrives with questions nobody prepared for:

- How was this infrastructure actually provisioned?
- Which identity does the app use when it talks to AWS?
- Can Service A talk to Service B when it absolutely should not?
- What happens when a pod dies at 2 a.m.?
- And when a bad deploy sneaks through… do we have enough telemetry to explain ourselves?

UPLOAD IMAGE HERE: docs/images/09-green-pods-monday.png
Caption: Green pods on Friday are not the same as answers on Monday.

That gap — between **deploying an application** and **operating a platform** — is where platform engineering earns its keep.

This article walks through a reference **golden path** for a Go microservice on **Amazon EKS**. The implementation uses Terraform, Helm, GitHub Actions with OpenID Connect (OIDC), EKS Pod Identity, Kubernetes NetworkPolicies, and Amazon CloudWatch Observability.

One promise up front: I will not pretend a Terraform file is a production incident report. We’ll clearly separate what is **implemented and locally validated** from what still needs a **live AWS run** before you put it on a conference slide as “proven in production.”

Because inventing CloudWatch screenshots is how you turn a good write-up into a bad week — and how a confident claim without a live run becomes a hot 1:1 with your supervisor when someone asks for the actual evidence.

## The big idea

**A golden path is not a pile of templates.**

It’s an engineered route that makes the safer choices the default choices:

- versioned infrastructure
- federated deployment identity (no long-lived AWS access keys in GitHub)
- workload-specific AWS permissions
- explicit network boundaries
- packaging that already includes probes, limits, and disruption budgets
- a documented path to metrics, logs, and (when verified) traces
- experiments you can re-run when something fails

Think of it like city planning.

You can let every developer invent their own roads, traffic lights, and house numbers. You’ll get “innovation.” You’ll also get accidents at every intersection.

Or you can pave a **main road** — still flexible enough for people to build different houses — but with sidewalks, street lights, and a fire hydrant already in place.

That’s a golden path. Not a prison. A street that already knows how traffic is supposed to move.

UPLOAD IMAGE HERE: docs/images/01-golden-path-main-road.png
Caption: A golden path is a paved road with sidewalks and hydrants — not a prison.

## Architecture at a glance

The design has four layers:

1. **Infrastructure** — Terraform builds a VPC, private worker subnets, EKS, add-ons, IAM, ECR, a demo S3 bucket, and VPC endpoints (including eks-auth for Pod Identity from private subnets).
2. **Delivery** — GitHub Actions CI and OIDC deploy: test, build, push an immutable image, Helm upgrade, then a health check.
3. **Runtime security** — EKS Pod Identity for the app, NetworkPolicies for pod traffic, and restricted Pod Security Standards on the namespace.
4. **Operations** — health and readiness probes, metrics, CloudWatch Observability configuration, and failure experiments.

The app itself is intentionally small: a Go HTTP service with `/`, `/healthz`, `/readyz`, `/metrics`, and a **bounded** `/work` endpoint for load testing. We keep the app boring so the platform can stay interesting.

UPLOAD IMAGE HERE: docs/images/02-four-layers-platform.png
Caption: Four layers — infrastructure, delivery, runtime security, operations.

UPLOAD IMAGE HERE: export docs/architecture.drawio.xml from diagrams.net (PNG or SVG)
Caption: End-to-end reference path on Amazon EKS (Terraform, OIDC, Pod Identity, NetworkPolicy, CloudWatch).

## What is locally validated vs still pending

This honesty section matters. Reviewers respect it.

**Locally validated today**

- Go service, unit tests, structured JSON logs, OpenTelemetry instrumentation
- Distroless non-root container build and local smoke test against health, metrics, and work endpoints
- Terraform fmt, init (local backend), and validate
- Helm lint and template rendering for NetworkPolicy, HPA, and hardened security context

**Implemented as configuration (needs a live GitHub Actions run)**

- SHA-pinned GitHub Actions workflows
- OIDC-based deploy path
- Fail-before-deploy checks
- Immutable image tag pattern: sha followed by the git commit

**Still PENDING live AWS evidence**

- terraform apply and a real EKS cluster
- Successful GitHub OIDC assume-role and deploy run URL
- Pod Identity caller identity and AccessDenied proof
- NetworkPolicy allow and deny behavioural proof
- Pod recovery and rollout observation
- HPA replica change under load
- CloudWatch metrics and logs actually arriving (traces only if observed)

Local validation that already passed:

    ./scripts/validate.sh
    # Result: LOCAL VALIDATION PASSED — 15 PASS, 0 FAIL

We’ll keep the live evidence section honest until a real deploy fills it. Until then: PENDING — not “imagine we saw AccessDenied.”

## 1. Provisioning the platform with Terraform

If your “platform” only exists in a colleague’s browser history of console clicks… congratulations, you’ve invented archaeological infrastructure.

Terraform keeps the foundation reviewable: VPC, subnets, NAT, EKS, managed node group, add-ons, IAM, ECR, S3, and endpoints — in version control next to the app.

### Visible assumptions

Good platforms admit their opinions. This implementation makes defaults explicit:

- AWS region (default us-east-1, configurable)
- EKS Kubernetes version (default 1.35, configurable)
- Two Availability Zones, public and private subnets
- Single NAT Gateway for demo cost (yes, that’s a trade-off — HA people, I see you)
- Node size and scaling limits
- Network policy enforcement mode (standard by default)
- Separate IAM roles for GitHub ECR push, GitHub deploy, app Pod Identity, and CloudWatch agents

### Kubernetes version: don’t hardcode folklore

EKS version support changes by time and by region. Copy-pasting an old version from a 2024 blog post is how demos die in the first terraform apply.

Do this before you apply:

    export AWS_REGION=us-east-1
    aws eks describe-cluster-versions --region "$AWS_REGION" \
      --query 'clusterVersions[].[clusterVersion,status,defaultVersion]' \
      --output table

    aws eks describe-cluster-versions --region "$AWS_REGION" \
      --query 'clusterVersions[?clusterVersion==`1.35`]'

Analogy time: picking a Kubernetes version without checking regional support is like booking a flight to a city that doesn’t have an airport anymore, then arguing with the airline about “but the blog said…”

### Private subnets and Pod Identity need a road to EKS Auth

Worker nodes sit in private subnets. For EKS Pod Identity to work there, nodes need reachability to the EKS Auth API. This design adds an interface VPC endpoint for eks-auth, plus helpful companions (STS, ECR, S3 gateway, CloudWatch Logs) so you’re not shoving every private-subnet conversation through NAT like it’s the only hallway in the building.

UPLOAD IMAGE HERE: docs/images/08-private-subnet-eks-auth.png
Caption: Private nodes need a designed road to EKS Auth — not “everything via NAT.”

### Cost and teardown are part of the design

NAT Gateways, EKS control planes, nodes, and telemetry ingestion are not free. A demo that never dies is just a subscription you forgot you started.

Document terraform destroy. Run it when you’re done. Future-you will send present-you a thank-you note (and maybe coffee).

**Local status:** Terraform configuration validates.  
**Live status:** apply and cluster creation still PENDING your approval and credentials.

## 2. Separating deployment identity from workload identity

This is the section I want people to remember after the talk.

There are at least two actors in every modern delivery path:

1. **Deployment identity** — GitHub Actions needs to publish an image and talk to EKS.
2. **Workload identity** — the running pod needs AWS permissions for its job (here: read a demo S3 bucket).

If you give both the same “admin-ish” role because it’s convenient… you’ve basically handed the office master key to both the building manager and the intern who’s only supposed to refill the printer.

UPLOAD IMAGE HERE: docs/images/03-two-keys-identity.png
Caption: Deployment identity and workload identity are different actors with different keys.

### GitHub Actions and OIDC (no long-lived keys)

Old habit: store AWS_ACCESS_KEY_ID in GitHub Secrets and hope nobody screenshots the logs.

Better habit: GitHub issues a short-lived OIDC token; IAM trusts token.actions.githubusercontent.com only when:

- aud equals sts.amazonaws.com
- sub matches your repository and branch (or environment)

This project creates two roles on purpose:

- **ECR role** — push and pull that repository only
- **Deploy role** — describe the cluster plus namespace-scoped EKS access for Helm

They are not interchangeable.

**Immutable subject claims:** repositories created after 15 July 2026 (or opted in) emit subjects like:

    repo:ORG@OWNER_ID/REPO@REPO_ID:ref:refs/heads/main

If your trust policy still expects the old name-only form, assume-role fails and everyone blames AWS. Support both formats in configuration.

Analogy: OIDC is a visitor badge that expires when the meeting ends. Long-lived access keys are a badge someone laminated in 2019 and still wears to every building in the city.

UPLOAD IMAGE HERE: docs/images/04-oidc-visitor-badge.png
Caption: OIDC is a visitor badge that expires; long-lived keys are laminated forever.

### EKS Pod Identity for the application

The app must not inherit “whatever the node role can do.” That’s how a humble HTTP service accidentally becomes able to rearrange your account.

Associate a Kubernetes service account with an IAM role via **EKS Pod Identity**:

- Trust principal: pods.eks.amazonaws.com with sts:AssumeRole and sts:TagSession
- Conditions: exact namespace, service account, and cluster ARN
- Permissions: s3:ListBucket and s3:GetObject on the demo bucket only

Validation must prove both sides:

1. The intended service account can get the expected caller identity and read the object.
2. An unauthorized action (for example CreateBucket) is denied.

A green Deployment is not proof. That’s like saying the restaurant is safe because the front door opens.

### Recap on identity

- **GitHub CI/CD:** OIDC into IAM roles, scoped to repo and branch, separate ECR vs deploy
- **App pods:** EKS Pod Identity, scoped to namespace plus service account plus cluster, S3 read only
- **CloudWatch agents:** IRSA in the amazon-cloudwatch namespace, telemetry permissions, not the app role

**Kindly note:** the CloudWatch agent trust can be namespace-scoped (amazon-cloudwatch star) rather than exact service-account names. That is better than sharing the app role, but it is not as tight as naming every agent SA. For publication honesty: call it “dedicated telemetry identity,” not “perfect least privilege for every agent SA,” unless you tighten it further.

## 3. Network boundaries with Kubernetes NetworkPolicies

IAM answers: “Can this identity call this AWS API?”

It does not answer: “Can this pod talk to that pod inside the cluster?”

That’s a different street entirely.

### Why manifests alone aren’t security

A NetworkPolicy YAML without an enforcing CNI is decorative. Pretty. Harmless. Like a “Speed Limit 30” sign on a road with no police and no speed bumps.

On EKS with the Amazon VPC CNI you must:

1. Enable network policy support (enableNetworkPolicy equals true)
2. Understand enforcement mode:
   - **standard** — brief default-allow window while policy applies
   - **strict** — default-deny from the start (DNS and friends must be explicitly allowed)

This golden path defaults to standard for demo sanity, and documents strict as a configuration option for teams ready for the extra homework (including CoreDNS dependencies).

### What the app policy actually does

For the demo service:

- **Ingress:** only pods labeled access=allowed on the app port (not everything in the namespace)
- **Egress:** DNS to CoreDNS in kube-system, plus TCP 443 for AWS API and S3 demos
- **Not:** unrestricted east-west chat inside the namespace

### Behavioural test (the only kind that counts)

Success looks like:

1. Allowed client reaches /healthz
2. Denied client fails to connect
3. DNS still works

kubectl apply success is configuration.  
A failed connection from the unlabeled pod is evidence.

Analogy: writing a guest list is not the same as having a bouncer. NetworkPolicy is the guest list. VPC CNI enforcement is the bouncer. Experiments are you watching the bouncer actually turn someone away.

UPLOAD IMAGE HERE: docs/images/05-network-bouncer.png
Caption: NetworkPolicy is the guest list; VPC CNI enforcement is the bouncer.

## 4. Packaging with Helm

Every team eventually rediscovers the same checklist:

- readiness vs liveness (they are not twins; stop dressing them identically)
- resource requests and limits
- non-root, drop capabilities, read-only root filesystem
- PodDisruptionBudget
- NetworkPolicy
- HPA (only meaningful if metrics exist)

Helm exists so that checklist becomes defaults, not folklore whispered in onboarding docs nobody reads.

### Probes, briefly

- **Liveness:** “Are you so broken we should restart you?”
- **Readiness:** “Should you receive traffic right now?”

If you use liveness for “I’m still warming up,” congratulations — you’ve invented a restart loop. It’s a popular genre of outage.

UPLOAD IMAGE HERE: docs/images/06-liveness-vs-readiness.png
Caption: Liveness restarts; readiness controls traffic. Mixing them invents restart loops.

### HPA honesty

An HPA object without a working metrics pipeline is a gym membership you never use. The chart can include HPA and the cluster can install metrics-server; observed replica changes under load still need a live experiment.

**Local status:** Helm lint and template confirm NetworkPolicy, HPA, and hardened security context render correctly.

## 5. Delivery without long-lived AWS keys

The pipeline is split on purpose.

### CI on every pull request and push

- Go format, vet, test, build
- Container build and image scanning
- Helm lint and template
- Fail closed when checks fail

Third-party GitHub Actions are pinned to commit SHAs. It’s slightly annoying. It’s also how you sleep better than depending on a floating latest tag from a repo you don’t own.

### Deploy on main

1. Run pre-deploy tests again
2. Assume the ECR role via OIDC and push an immutable sha-gitsha tag
3. Assume the deploy role and run helm upgrade --install
4. Wait for rollout
5. Confirm /readyz

Image tags are immutable. latest is for demos that enjoy mystery novels in production.

Analogy: CI is the driver’s license exam. Deploy is the car keys. OIDC is the valet ticket that only works for your car, today — not a rusty master key left under the mat since 2018.

UPLOAD IMAGE HERE: docs/images/10-delivery-oidc-pipeline.png
Caption: CI is the exam; OIDC is today’s valet ticket; image tags stay immutable.

**Local status:** workflows are designed and reviewed in source control.  
**Live status:** Actions run URL and image digest PENDING.

## 6. Making the system observable

A pod can be Ready while users are having a terrible day. Kubernetes health is necessary; it is not sufficient.

### Three signal types

**Metrics** answer: are we within expected limits?  
In this project: application /metrics via OpenTelemetry to a Prometheus registry, plus cluster telemetry through CloudWatch Observability with OTel Container Insights configured.

**Logs** answer: what happened in this event?  
In this project: structured JSON logs with request IDs. Those IDs stay in logs — not as high-cardinality metric labels.

**Traces** answer: where did this request go?  
In this project: OpenTelemetry SDK with optional OTLP export. Claim distributed tracing only if you can see a real trace in the destination.

Installing an agent is not the same as having useful telemetry. That’s like buying a security camera and never plugging it into power, then pointing at the box and saying “we have CCTV.”

UPLOAD IMAGE HERE: docs/images/07-three-signals-observability.png
Caption: Metrics, logs, and traces — installing an agent is not the same as observing useful signals.

### CloudWatch Observability path

The design installs the amazon-cloudwatch-observability add-on with:

- OTel Container Insights enabled (recommended path)
- classic Container Insights disabled by default for demo cost control
- a dedicated IRSA role for agents in amazon-cloudwatch — not the application Pod Identity role

App OTLP can target the in-cluster agent endpoint when export is enabled in deploy configuration.

Verify after deploy with real console or CLI proof. Until then: configuration exists; arrival of data is PENDING.

Also: more telemetry is not automatically better telemetry. Cardinality, retention, and sampling are budget line items wearing lab coats.

## 7. Testing failure, not just the happy path

A platform that only works on the first deploy is a demo. A platform you can break on purpose and still explain is a practice.

Useful experiments:

- Pod recovery: delete a pod and watch the Deployment replace it
- Rollout behaviour: confirm rollout status and know how to undo
- Workload identity: caller identity, allowed S3 read, denied unauthorized action
- Network isolation: allowed traffic, denied traffic, DNS still works
- Autoscaling: bounded load through /work, then watch HPA decisions
- Observability: generate traffic and confirm signals in CloudWatch

The /work endpoint must be capped. Load testing should not be a denial-of-service button disguised as a feature. We’re building a golden path, not a chaos gremlin with root access and a grin.

Important: do not paste example outputs into the article as if they were real. Mark examples clearly. Record only observed results.

## 8. What this golden path does not solve

A reference implementation that pretends to be a complete production platform is selling protein powder as a gym.

Still on you for production:

- certificate and secret lifecycle
- admission policies
- deeper supply-chain provenance
- backup, disaster recovery, and multi-environment promotion
- formal SLOs and alert routing
- a fuller threat model

Also restated because it matters:

- NetworkPolicy without enforcement is not a control
- HPA without observed scaling is not autoscaling
- Tracing without a visible trace is not distributed tracing

Boundaries are intentional. Golden paths give strong defaults — they don’t abolish judgment.

## Implementation evidence

Fill this after a real AWS and GitHub run. Do not invent values.

- **Terraform:** validate done locally; apply, region, and cluster version PENDING
- **Go service:** local go test, build, and container smoke PASSED
- **CI/CD:** GitHub Actions run URL and image digest PENDING
- **Pod Identity:** sts get-caller-identity from the app service account PENDING
- **Least privilege:** denied operation output PENDING
- **NetworkPolicy:** allowed, blocked, and DNS results PENDING
- **Pod recovery:** delete and replacement observation PENDING
- **Autoscaling:** HPA metrics and replica change, or explicitly “not observed” PENDING
- **CloudWatch:** query or screenshot of real metrics and logs PENDING; traces only if seen

**Implementation repository:** https://github.com/gbengafagbola/eks-go-golden-path  
**Environment:** insert AWS region and verified EKS Kubernetes version after apply  
**Cost note:** insert approximate runtime and teardown confirmation  
**Local gates:** scripts/validate.sh resulted in 15 PASS and 0 FAIL

## How I’d present this

1. Hook: green pods, bad Monday questions
2. Thesis: golden path equals safer defaults as the paved road
3. Four layers with the architecture diagram on screen
4. Identity story: OIDC versus Pod Identity — this is the mic-drop section
5. NetworkPolicy: guest list versus bouncer
6. Honesty slide: local validation versus live evidence
7. Live demo plan when you have a cluster: delete a pod, show S3 deny, show blocked network client
8. Close: reliability should not depend on every developer remembering a checklist

If the Wi-Fi dies mid-talk, joke that this is why we practice failure experiments — then fall back to the architecture diagram. Always have a diagram. Diagrams don’t need DHCP.

## Conclusion

The most useful platform abstractions don’t hide complexity. They make good decisions repeatable.

By combining Terraform, EKS, Helm, GitHub Actions OIDC, EKS Pod Identity, NetworkPolicies, and CloudWatch Observability into one path, we stop treating security and operations like optional homework.

The deeper lesson is simple enough to put on a slide:

Reliability and security should not depend on every developer remembering a checklist. They should be built into the road developers already use to ship.

That’s the value of a golden path: not making the hard parts disappear — making the safer, more observable way of doing things feel like the natural way to build.

Now go pave the road. And please… tear down the demo cluster when you’re done. NAT Gateways have enough fans already.

## References

- Amazon EKS Pod Identity: https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html
- Create an EKS Pod Identity association: https://docs.aws.amazon.com/eks/latest/userguide/pod-id-association.html
- EKS network policy configuration: https://docs.aws.amazon.com/eks/latest/userguide/cni-network-policy-configure.html
- CloudWatch OTel Container Insights: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/container-insights-eks-otel.html
- GitHub Actions OIDC in AWS: https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws
- OpenID Connect reference (immutable subjects): https://docs.github.com/en/actions/reference/security/oidc
- Amazon EKS Best Practices Guide: https://docs.aws.amazon.com/eks/latest/best-practices/
