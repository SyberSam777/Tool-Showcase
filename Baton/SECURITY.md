# Security Policy

## Reporting a vulnerability

Open a private security advisory via GitHub's "Report a vulnerability" flow. Do not open a public
issue. Expect an acknowledgement within 72 hours.

## Threat model

Baton exists to bound the authority of untrusted proposers. The assumptions:

| Trusted | Untrusted |
|---|---|
| The Kubernetes API server and its RBAC | Any proposer, including `triaged` |
| Baton's controller identity | The content of `Action.spec` |
| `AutonomyPolicy` objects (RBAC-restricted) | Evidence referenced by an Action |

Consequences of that split:

- **Proposers never receive cluster credentials.** A proposer's ServiceAccount holds
  `create`/`get`/`list` on `actions` and nothing else.
- **`AutonomyPolicy` is a privileged object.** Write access to it is equivalent to write access to
  the cluster. Restrict it to platform admins and gate it in CI.
- **`defaultAutonomy` fails closed** (`deny`). An Action whose class/namespace matches no rule is
  rejected, not permitted.
- **Evidence is content-addressed.** `sha256:` refs mean a proposal cannot cite mutable state.
- **Dry-run is the default execution mode.** Committing requires explicit configuration.

## Supply chain

Releases are signed with keyless cosign and ship a Syft SBOM. CI gates on gitleaks, gosec, semgrep,
hadolint, and Trivy at HIGH/CRITICAL. Deployments should verify the signature at admission — a
Kyverno `verifyImages` rule is the intended enforcement point.
