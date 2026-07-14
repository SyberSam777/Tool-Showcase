# Security Policy

## Reporting a vulnerability

Use GitHub's private "Report a vulnerability" flow. Do not open a public issue.

## This repository breaks things on purpose

`misbehave` is deliberately hostile software: it leaks memory, fills disks, generates 500s, and
floods logs. That is its function. It carries the following guardrails, and they are not optional.

- **Never run it in a cluster you care about.** It ships with a `traffic-lab` namespace, a
  ResourceQuota, and a LimitRange so a runaway scenario is bounded by the substrate, not by good
  intentions.
- **All scripts are dry-run by default.** `hack/run-matrix.sh` prints its plan and does nothing
  until `--apply`.
- **The PII is synthetic.** `log-flood` emits SSNs in the reserved `900-xx-xxxx` range and emails at
  `example.com` only. CI has a gate (`no-real-pii`) that fails the build on anything outside those
  ranges. Do not weaken it.
- **`disk-fill` writes only inside its own PVC** and stops at a configured ceiling.

## Supply chain

gitleaks, golangci-lint, hadolint, and Trivy (HIGH/CRITICAL) gate every PR. Tagged images are
cosign-signed keylessly and carry SBOM + provenance attestations.
