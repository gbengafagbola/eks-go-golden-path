# Repository Audit

**Date:** 2026-11-23  
**Workspace:** `/Users/ofagbola/Documents/workspace/sre`

## Summary

The repository was **empty** at the start of this work. There was no prior Terraform, Go application, Helm chart, GitHub Actions workflow, experiment script, or documentation to preserve.

This project is a **greenfield reference implementation** of the golden path described in *Building a Secure, Observable Golden Path for Go Microservices on Amazon EKS*.

## Audit findings

| Area | Status before implementation |
| ---- | ---------------------------- |
| Terraform (`terraform/`) | Missing |
| Go application (`app/`) | Missing |
| Container image (`Dockerfile`) | Missing |
| Helm chart (`helm/platform-demo/`) | Missing |
| GitHub Actions (`.github/workflows/`) | Missing |
| Validation scripts (`scripts/`) | Missing |
| Experiments (`experiments/`) | Missing |
| Documentation (`docs/`, `README.md`) | Missing |

## Article claim baseline

All article claims started as **unsupported** until implemented and validated:

1. Terraform-provisioned VPC + EKS — requires implementation + live `apply`
2. GitHub Actions OIDC (no long-lived keys) — requires implementation + live workflow run
3. EKS Pod Identity least privilege — requires implementation + live pod identity test
4. NetworkPolicy enforcement via VPC CNI — requires implementation + live connectivity tests
5. Helm packaging with probes, PDB, HPA, security context — local lint/template + live rollout
6. CloudWatch Observability / OTel Container Insights — requires live cluster evidence
7. Failure experiments (recovery, identity deny, network deny, HPA) — require live cluster

## Implementation approach

Build the full stack from scratch, run every **local** validation that does not mutate AWS, and document exact live-deployment and evidence procedures without inventing results.
