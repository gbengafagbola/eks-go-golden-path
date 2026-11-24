# Building a Secure, Observable Golden Path for Go Microservices on Amazon EKS

*From infrastructure provisioning to workload identity, network isolation, continuous delivery, and operational visibility — and why “it deployed” is not the same as “it’s ready.”*

---

Hey guys!

Thanks for joining. Today we’re going to talk about something that quietly burns engineering teams: a Kubernetes deployment that looks successful… and still leaves you with an operational mess.

The pods are green. The service responds. Someone drops a “shipped 🚀” in Slack. Then Monday morning arrives with questions nobody prepared for:

- How was this infrastructure actually provisioned?
- Which identity does the app use when it talks to AWS?
- Can Service A talk to Service B when it absolutely should not?
- What happens when a pod dies at 2 a.m.?
- And when a bad deploy sneaks through… do we have enough telemetry to explain ourselves?

That gap — between **deploying an application** and **operating a platform** — is where platform engineering earns its keep.

This article walks through a reference **golden path** for a Go microservice on **Amazon EKS**. The implementation lives in this repo and uses Terraform, Helm, GitHub Actions (OIDC), EKS Pod Identity, Kubernetes NetworkPolicies, and Amazon CloudWatch Observability.

One promise up front: I will not pretend a Terraform file is a production incident report. We’ll clearly separate what is **implemented and locally validated** from what still needs a **live AWS run** before you put it on a conference slide as “proven in production.”

Because inventing CloudWatch screenshots is how articles lose credibility — and how speaking proposals get side-eyed by reviewers who have actually been on-call.

---

## The big idea (say this on stage)

**A golden path is not a pile of templates.**

It’s an engineered route that makes the safer choices the *default* choices:

- versioned infrastructure
- federated deployment identity (no long-lived AWS keys in GitHub)
- workload-specific AWS permissions
- explicit network boundaries
- packaging that already includes probes, limits, and disruption budgets
- a documented path to metrics, logs, and (when verified) traces
- experiments you can re-run when something fails

Think of it like city planning.

You can let every developer invent their own roads, traffic lights, and house numbers. You’ll get “innovation.” You’ll also get accidents at every intersection.

Or you can pave a **main road** — still flexible enough for people to build different houses — but with sidewalks, street lights, and a fire hydrant already in place.

That’s a golden path. Not a prison. A street that already knows how traffic is supposed to move.

---

## Architecture at a glance

The design has four layers:

1. **Infrastructure** — Terraform builds a VPC, private worker subnets, EKS, add-ons, IAM, ECR, a demo S3 bucket, and VPC endpoints (including `eks-auth` for Pod Identity from private subnets).
2. **Delivery** — GitHub Actions CI + OIDC deploy: test → build → push immutable image → Helm upgrade → health check.
3. **Runtime security** — EKS Pod Identity for the app, NetworkPolicies for pod traffic, restricted Pod Security Standards on the namespace.
4. **Operations** — health/readiness probes, metrics, CloudWatch Observability configuration, and failure experiments under `experiments/`.

The app itself is intentionally small: a Go HTTP service with `/`, `/healthz`, `/readyz`, `/metrics`, and a **bounded** `/work` endpoint for load testing. We keep the app boring so the platform can stay interesting.

> **Diagram:** Import [`docs/architecture.drawio.xml`](./architecture.drawio.xml) into [diagrams.net](https://app.diagrams.net/) for the AWS-icon architecture map. Export PNG/SVG for slides.

---

## A quick honesty table (please keep this in the article)

| Concern | Status today |
| ------- | ------------ |
| Go service, tests, structured logs, OTel instrumentation | **Locally validated** |
| Distroless non-root container + smoke test | **Locally validated** |
| Terraform fmt / init / validate | **Locally validated** |
| Helm lint/template (NetworkPolicy, HPA, security context) | **Locally validated** |
| GitHub Actions workflows (SHA-pinned, OIDC, fail-before-deploy) | **Implemented as config** (needs a live Actions run) |
| `terraform apply`, live cluster, Pod Identity deny test, NetworkPolicy enforcement, HPA scale-out, CloudWatch data | **PENDING live AWS evidence** |

Local validation command (this actually ran green):

```bash
./scripts/validate.sh
# LOCAL VALIDATION PASSED — 15 PASS, 0 FAIL
```

We’ll fill the live evidence table at the end after a real deploy. Until then: **PENDING**, not “imagine we saw AccessDenied.”

---

## 1. Provisioning the platform with Terraform

If your “platform” only exists in a colleague’s browser history of console clicks… congratulations, you’ve invented archaeological infrastructure.

Terraform keeps the foundation reviewable: VPC, subnets, NAT, EKS, managed node group, add-ons, IAM, ECR, S3, and endpoints — in version control next to the app.

### Visible assumptions (good platforms admit their opinions)

This repo makes defaults explicit:

- AWS region (default `us-east-1`, configurable)
- EKS Kubernetes version (default `1.35`, configurable)
- Two AZs, public + private subnets
- Single NAT Gateway for **demo cost** (yes, that’s a trade-off — HA people, I see you)
- Node size/scaling limits
- Network policy enforcement mode (`standard` by default)
- Separate IAM roles for GitHub ECR push, GitHub deploy, app Pod Identity, and CloudWatch agents

### Kubernetes version: don’t hardcode folklore

EKS version support changes by time **and** by region. Copy-pasting `1.2x` from a 2024 blog post is how demos die in the first `terraform apply`.

**Do this before you apply:**

```bash
export AWS_REGION=us-east-1
aws eks describe-cluster-versions --region "$AWS_REGION" \
  --query 'clusterVersions[].[clusterVersion,status,defaultVersion]' \
  --output table

aws eks describe-cluster-versions --region "$AWS_REGION" \
  --query 'clusterVersions[?clusterVersion==`1.35`]'
```

Analogy time: picking a Kubernetes version without checking regional support is like booking a flight to a city that doesn’t have an airport anymore, then arguing with the airline about “but the blog said…”

### Private subnets and Pod Identity need a road to EKS Auth

Worker nodes sit in **private** subnets. For EKS Pod Identity to work there, nodes need reachability to the EKS Auth API. This repo adds an **interface VPC endpoint** for `eks-auth`, plus helpful companions (STS, ECR, S3 gateway, CloudWatch Logs) so you’re not shoving every private-subnet conversation through NAT like it’s the only hallway in the building.

### Cost and teardown are part of the design

NAT Gateways, EKS control planes, nodes, and telemetry ingestion are not free. A demo that never dies is just a subscription you forgot you started.

Document `terraform destroy`. Run it when you’re done. Future-you will send present-you a thank-you note (and maybe coffee).

**Local status:** Terraform configuration validates.  
**Live status:** `apply` / cluster creation still PENDING your approval and credentials.

---

## 2. Separating deployment identity from workload identity

This is the section I want people to remember after the talk.

There are **at least two actors** in every modern delivery path:

1. **Deployment identity** — GitHub Actions needs to publish an image and talk to EKS.
2. **Workload identity** — the running pod needs AWS permissions for *its* job (here: read a demo S3 bucket).

If you give both the same “admin-ish” role because it’s convenient… you’ve basically handed the office master key to both the building manager and the intern who’s only supposed to refill the printer.

### GitHub Actions + OIDC (no long-lived keys)

Old habit: store `AWS_ACCESS_KEY_ID` in GitHub Secrets and hope nobody screenshots the logs.

Better habit: GitHub issues a short-lived OIDC token; IAM trusts `token.actions.githubusercontent.com` only when:

- `aud` = `sts.amazonaws.com`
- `sub` matches **your** repo and branch (or environment)

This project creates **two** roles:

- **ECR role** — push/pull that repository only
- **Deploy role** — describe the cluster + namespace-scoped EKS access for Helm

They are not interchangeable. On purpose.

**Immutable subject claims:** repositories created after **15 July 2026** (or opted-in) emit subjects like:

```text
repo:ORG@OWNER_ID/REPO@REPO_ID:ref:refs/heads/main
```

If your trust policy still expects the old name-only form, assume-role fails and everyone blames AWS. Terraform variables cover both formats — use them.

Analogy: OIDC is a visitor badge that expires when the meeting ends. Long-lived access keys are a badge someone laminated in 2019 and still wears to every building in the city.

### EKS Pod Identity for the application

The app must not inherit “whatever the node role can do.” That’s how a humble HTTP service accidentally becomes able to rearrange your account.

We associate a Kubernetes service account with an IAM role via **EKS Pod Identity**:

- Trust: `pods.eks.amazonaws.com` with `sts:AssumeRole` + `sts:TagSession`
- Conditions: exact namespace, service account, and cluster ARN
- Permissions: `s3:ListBucket` / `s3:GetObject` on the demo bucket only

**Validation must prove both sides:**

1. The intended SA can get the expected caller identity and read the object.
2. An unauthorized action (e.g. `CreateBucket`) is denied.

A green Deployment is not proof. That’s like saying the restaurant is safe because the front door opens.

Live proof lives in `experiments/03-workload-identity.sh` — run it after apply, paste real output into the evidence template.

### Recap — identity

| Actor | Mechanism | Scope |
| ----- | --------- | ----- |
| GitHub CI/CD | OIDC → IAM roles | Repo/branch-scoped; separate ECR vs deploy |
| App pods | EKS Pod Identity | Namespace + SA + cluster; S3 read only |
| CloudWatch agents | IRSA in `amazon-cloudwatch` | Telemetry permissions — **not** the app role |

**Kindly note:** the CloudWatch agent trust currently allows `system:serviceaccount:amazon-cloudwatch:*` (namespace-scoped). That’s better than sharing the app role, but it is **not** as tight as naming exact agent SAs. For speaking/publication honesty: call it “dedicated telemetry identity,” not “perfect least privilege for every agent SA,” unless you tighten it further.

---

## 3. Network boundaries with Kubernetes NetworkPolicies

IAM answers: “Can this identity call this AWS API?”

It does **not** answer: “Can this pod talk to that pod inside the cluster?”

That’s a different street entirely.

### Why manifests alone aren’t security

A NetworkPolicy YAML without an enforcing CNI is decorative. Pretty. Harmless. Like a “Speed Limit 30” sign on a road with no police and no speed bumps.

On EKS with the Amazon VPC CNI you must:

1. Enable network policy support (`enableNetworkPolicy=true`)
2. Understand enforcement mode:
   - **standard** — brief default-allow window while policy applies
   - **strict** — default-deny from the start (DNS and friends must be explicitly allowed)

This golden path defaults to **standard** for demo sanity, and documents `strict` as a Terraform variable for teams ready for the extra homework (including CoreDNS dependencies).

### What the app policy actually does

For `platform-demo`:

- **Ingress:** only pods labeled `access=allowed` on the app port  
  (not “everything in the namespace” — that would make the deny test a comedy sketch)
- **Egress:** DNS to CoreDNS in `kube-system`, plus TCP/443 for AWS API/S3 demos
- **Not:** unrestricted east-west chat inside the namespace

### Behavioural test (the only kind that counts)

```bash
./experiments/04-network-isolation.sh
```

Success looks like:

1. Allowed client → `/healthz` works  
2. Denied client → connection fails  
3. DNS still works  

`kubectl apply` success is configuration.  
Failed wget from the unlabeled pod is evidence.

Analogy: writing a guest list is not the same as having a bouncer. NetworkPolicy is the guest list. VPC CNI enforcement is the bouncer. Experiments are you watching the bouncer actually turn someone away.

---

## 4. Packaging with Helm (so humans don’t forget the boring essentials)

Every team eventually rediscovers the same checklist:

- readiness vs liveness (they are not twins; stop dressing them identically)
- resource requests/limits
- non-root, drop capabilities, read-only root filesystem
- PodDisruptionBudget
- NetworkPolicy
- HPA (only meaningful if metrics exist)

Helm exists so that checklist becomes **defaults**, not folklore whispered in onboarding docs nobody reads.

### Probes, briefly

- **Liveness:** “Are you so broken we should restart you?”
- **Readiness:** “Should you receive traffic right now?”

If you use liveness for “I’m still warming up,” congratulations — you’ve invented a restart loop. It’s a popular genre of outage.

### HPA honesty

An HPA object without a working metrics pipeline is a gym membership you never use. The chart includes HPA; `metrics-server` is installed via Terraform; **observed replica changes under load** still need `experiments/05-autoscaling.sh` on a live cluster.

**Local status:** Helm lint/template confirms NetworkPolicy, HPA, and hardened security context render correctly.

---

## 5. Delivery without long-lived AWS keys

The pipeline is split on purpose:

### CI (every PR / push)

- Go format, vet, test, build
- Container build + Trivy
- Helm lint/template
- Fail closed when checks fail

Third-party Actions are pinned to **commit SHAs** (with version comments). It’s slightly annoying. It’s also how you sleep better than “latest tag from a repo I don’t own.”

### Deploy (`main`)

1. Run pre-deploy tests again (`needs: test`)
2. Assume ECR role via OIDC → push `sha-<gitsha>`
3. Assume deploy role → `helm upgrade --install`
4. Wait for rollout
5. Port-forward and hit `/readyz`

Image tags are immutable. `latest` is for demos that enjoy mystery novels in production.

Analogy: CI is the driver’s license exam. Deploy is the car keys. OIDC is the valet ticket that only works for *your* car, *today*, not a rusty master key left under the mat since 2018.

**Local status:** workflows are in the repo and reviewed.  
**Live status:** Actions run URL + image digest PENDING.

---

## 6. Making the system observable (without drowning in noise)

A pod can be `Ready` while users are having a terrible day. Kubernetes health is necessary; it is not sufficient.

### Three signal types (keep these distinct on stage)

| Signal | Question it answers | In this project |
| ------ | ------------------- | --------------- |
| **Metrics** | Are we within expected limits? | App `/metrics` (OTel → Prometheus registry); cluster via CloudWatch Observability / OTel Container Insights config |
| **Logs** | What happened in this event? | Structured JSON logs with request IDs (IDs stay in logs — **not** as high-cardinality metric labels) |
| **Traces** | Where did this request go? | OTel SDK + optional OTLP export — **claim only if you see a real trace** |

Installing an agent is not the same as having useful telemetry. That’s like buying a security camera and never plugging it into power, then pointing at the box and saying “we have CCTV.”

### CloudWatch Observability path

Terraform installs `amazon-cloudwatch-observability` with:

- `otelContainerInsights.enabled = true` (recommended path)
- classic Container Insights disabled by default (demo cost control)
- a **dedicated** IRSA role for agents in `amazon-cloudwatch` — not the application Pod Identity role

App OTLP can target the in-cluster agent endpoint when `OTEL_ENABLE_OTLP_EXPORT=true` (enabled in the deploy workflow).

**Verify after deploy** with `experiments/06-observability.sh` and real console/CLI proof. Until then: configuration exists; arrival of data is PENDING.

Also: more telemetry is not automatically better telemetry. Cardinality, retention, and sampling are budget line items wearing lab coats.

---

## 7. Testing failure, not just the happy path

A platform that only works on the first deploy is a demo. A platform you can *break on purpose* and still explain is a practice.

This repo ships experiments:

| Experiment | What you’re proving |
| ---------- | ------------------- |
| `01-pod-recovery.sh` | Deployment controller replaces a deleted pod |
| `02-rollout.sh` | Rollout status / rollback muscle memory |
| `03-workload-identity.sh` | Caller identity + allow + deny |
| `04-network-isolation.sh` | Allow / deny / DNS |
| `05-autoscaling.sh` | Metrics + HPA behaviour under bounded `/work` load |
| `06-observability.sh` | Telemetry verification guide |

The `/work` endpoint is capped (duration and CPU millis). Load testing should not be a denial-of-service button disguised as a feature. We’re building a golden path, not a chaos gremlin with root access and a grin.

**Important:** do not paste “example” outputs into the article as if they were real. Mark examples clearly. Fill [`docs/evidence-template.md`](./evidence-template.md) only with observed results.

---

## 8. What this golden path does *not* solve

A reference implementation that pretends to be a complete production platform is selling protein powder as a gym.

Still on you for production:

- certificate and secret lifecycle
- admission policies (OPA/Kyverno and friends)
- deeper supply-chain provenance
- backup / DR / multi-environment promotion
- formal SLOs and alert routing
- a fuller threat model

Also restated because it matters:

- NetworkPolicy without enforcement ≠ control  
- HPA without observed scaling ≠ autoscaling  
- Tracing without a visible trace ≠ distributed tracing  

Boundaries are intentional. Golden paths give strong defaults — they don’t abolish judgment.

---

## Implementation evidence (fill after live run — do not invent)

| Validation | Evidence to record | Status now |
| ---------- | ------------------ | ---------- |
| Terraform | `terraform validate` (done locally); `apply` + region + cluster version | Validate ✅ · Apply PENDING |
| Go service | `go test ./...` + build + container smoke | ✅ Local |
| CI/CD | GitHub Actions run URL + image digest/`sha-<git>` | PENDING |
| Pod Identity | `sts get-caller-identity` from app SA | PENDING |
| Least privilege | Denied operation output (e.g. AccessDenied) | PENDING |
| NetworkPolicy | Allowed + blocked + DNS results | PENDING |
| Pod recovery | Delete pod → replacement ready | PENDING |
| Autoscaling | HPA metrics + replica change (or “not observed”) | PENDING |
| CloudWatch | Query/screenshot of real metrics/logs; traces only if seen | PENDING |

**Implementation repository:** *[insert public GitHub URL after you push]*  
**Environment:** *[insert region + verified EKS version after apply]*  
**Cost note:** *[insert runtime hours + teardown confirmation]*  
**Local gates:** `./scripts/validate.sh` → **15 PASS / 0 FAIL** (2026-11-23)

Architecture import file: `docs/architecture.drawio.xml`

---

## How I’d present this (speaking tip)

1. **Hook:** green pods, bad Monday questions.  
2. **Thesis:** golden path = safer defaults as the paved road.  
3. **Four layers** with the draw.io diagram on screen.  
4. **Identity story** (OIDC vs Pod Identity) — this is your “mic drop” section.  
5. **NetworkPolicy** — guest list vs bouncer.  
6. **Honesty slide** — local validation vs live evidence. Reviewers love this; it signals maturity.  
7. **Live demo plan** (when you have a cluster): delete a pod, show deny on S3, show blocked network client.  
8. **Close:** reliability shouldn’t depend on every developer remembering a checklist.

If the Wi-Fi dies mid-talk, joke that this is why we practice failure experiments — then fall back to the architecture diagram. Always have a diagram. Diagrams don’t need DHCP.

---

## Conclusion

The most useful platform abstractions don’t hide complexity. They make good decisions **repeatable**.

By combining Terraform, EKS, Helm, GitHub Actions OIDC, EKS Pod Identity, NetworkPolicies, and CloudWatch Observability into one path, we stop treating security and operations like optional homework.

The deeper lesson is simple enough to put on a slide:

> Reliability and security should not depend on every developer remembering a checklist.  
> They should be built into the road developers already use to ship.

That’s the value of a golden path: not making the hard parts disappear — making the safer, more observable way of doing things feel like the natural way to build.

Now go pave the road. And please… tear down the demo cluster when you’re done. NAT Gateways have enough fans already.

---

## References

- [Amazon EKS Pod Identity](https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html)
- [Create an EKS Pod Identity association](https://docs.aws.amazon.com/eks/latest/userguide/pod-id-association.html)
- [EKS network policy configuration](https://docs.aws.amazon.com/eks/latest/userguide/cni-network-policy-configure.html)
- [CloudWatch Container Insights / OTel CI](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/container-insights-eks-otel.html)
- [GitHub Actions: Configuring OpenID Connect in AWS](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws)
- [OpenID Connect reference (immutable subjects)](https://docs.github.com/en/actions/reference/security/oidc)
- [Amazon EKS Best Practices Guide](https://docs.aws.amazon.com/eks/latest/best-practices/)

---

*Written for engineers who’ve watched a green dashboard lie with a straight face — and for the talk proposal that needs both warmth and receipts.*
