# Article image upload map

Upload these PNGs into the AWS Builder Center editor at the markers in `docs/article-aws-builder-center.md`.

Also export the architecture diagram once:

- Source: `docs/architecture.drawio.xml` (diagrams.net + AWS icons)
- Export: PNG or SVG → upload where the article says **Architecture diagram**

| # | File | Insert after | Why it belongs there |
|---|------|--------------|----------------------|
| 09 | `09-green-pods-monday.png` | Opening hook (after Monday questions) | Visualizes “green pods / shipped Slack” vs operational gap |
| 01 | `01-golden-path-main-road.png` | “The big idea” city-planning analogy | Chaos roads vs paved golden path |
| 02 | `02-four-layers-platform.png` | “Architecture at a glance” four layers | Stack map before the detailed sections |
| — | Architecture draw.io export | Same section, after four-layers figure | Full AWS-icon system diagram |
| 08 | `08-private-subnet-eks-auth.png` | Private subnets / Pod Identity road | Explains eks-auth VPC endpoint necessity |
| 03 | `03-two-keys-identity.png` | Start of identity section | Deploy key vs workload key |
| 04 | `04-oidc-visitor-badge.png` | OIDC visitor-badge analogy | Short-lived OIDC vs laminated keys |
| 05 | `05-network-bouncer.png` | NetworkPolicy guest-list / bouncer | YAML vs CNI enforcement + experiments |
| 06 | `06-liveness-vs-readiness.png` | Helm probes subsection | Restart vs traffic admission |
| 10 | `10-delivery-oidc-pipeline.png` | Delivery / CI→deploy analogy | Exam → valet ticket → immutable tag → /readyz |
| 07 | `07-three-signals-observability.png` | Observability three signals | Metrics / logs / traces + “unplugged CCTV” |

## Suggested captions (paste under each image)

1. **09** — Green pods on Friday are not the same as answers on Monday.
2. **01** — A golden path is a paved road with sidewalks and hydrants — not a prison.
3. **02** — Four layers: infrastructure, delivery, runtime security, operations.
4. **Architecture** — End-to-end reference path on Amazon EKS (Terraform, OIDC, Pod Identity, NetworkPolicy, CloudWatch).
5. **08** — Private nodes need a designed road to EKS Auth — not “everything via NAT.”
6. **03** — Deployment identity and workload identity are different actors with different keys.
7. **04** — OIDC is a visitor badge that expires; long-lived keys are laminated forever.
8. **05** — NetworkPolicy is the guest list; VPC CNI enforcement is the bouncer.
9. **06** — Liveness restarts; readiness controls traffic. Mixing them invents restart loops.
10. **10** — CI is the exam; OIDC is today’s valet ticket; tags stay immutable.
11. **07** — Installing telemetry is not the same as observing useful signals.

## Regenerate

```bash
.venv-img/bin/python docs/images/generate_figures.py
```
