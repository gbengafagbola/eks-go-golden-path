# GitHub Actions pin map

Third-party actions are pinned to commit SHAs. Versions below are the upstream tags those SHAs correspond to.

| Action | Tag | Commit SHA |
| ------ | --- | ---------- |
| `actions/checkout` | v4.2.2 | `11bd71901bbe5b1630ceea73d27597364c9af683` |
| `actions/setup-go` | v5.4.0 | `0aaccfd150d50ccaeb58ebd88d36e91967a5f35b` |
| `docker/setup-buildx-action` | v3.10.0 | `b5ca514318bd6ebac0fb2aedd5d36ec1b5c232a2` |
| `azure/setup-helm` | v4.3.0 | `b9e51907a09c216f16ebe8536097933489208112` |
| `aws-actions/configure-aws-credentials` | v4.1.0 | `ececac1a45f3b08a01d2dd070d28d111c5fe6722` |
| `aws-actions/amazon-ecr-login` | v2.0.1 | `062b18b96a7aff071d4dc91bc00c4c1a7945b076` |

Image scanning in CI uses the Trivy CLI install script (`v0.58.1`) rather than `aquasecurity/trivy-action`, to avoid action-tag ambiguity.
