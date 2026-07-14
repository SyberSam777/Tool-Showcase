# Security Policy

## Reporting a vulnerability

Use GitHub's private "Report a vulnerability" flow. Do not open a public issue.

## Design posture

lode's security value is **redaction before egress**. Sensitive data is scrubbed in the tailer
process on the node, before it crosses a network boundary. A misconfigured redaction ruleset is
therefore the highest-severity failure mode in this project — treat `redact.yaml` as production
policy, keep it in version control, and gate changes to it in CI.

## Runtime hardening

- `FROM scratch`, static musl binary. No shell, no libc, no package manager in the image.
- Runs as UID 65532, `readOnlyRootFilesystem: true`, all capabilities dropped.
- Requires `hostPath` reads on `/var/log/containers` and `/var/lib/lode` — the only privileged
  surface. Both are mounted read-only except the checkpoint dir.
- `seLinuxOptions.type: spc_t` is required under enforcing SELinux on RHEL. If your policy
  prohibits `spc_t`, use the narrower custom module in `deploy/selinux/lode.te` instead.
- Elasticsearch credentials come from a Secret via env, never from the config file, and are never
  logged — lode's own logger has a deny-list on `LODE_ES_PASS`.

## Supply chain

`cargo-audit` and `cargo-deny` (bans/licenses/sources) gate every PR. Releases carry a Syft SBOM and
a keyless cosign signature.
