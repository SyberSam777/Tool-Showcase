# Baton

[![CI](https://github.com/jlawrence/baton/actions/workflows/ci.yml/badge.svg)](https://github.com/jlawrence/baton/actions/workflows/ci.yml)
[![Go Reference](https://pkg.go.dev/badge/github.com/jlawrence/baton.svg)](https://pkg.go.dev/github.com/jlawrence/baton)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

**A deterministic Kubernetes control plane that lets AI agents *propose* changes and never lets them *make* changes.**

Baton is the execution and admission layer for the Trinity platform. Any actor that wants to
change cluster state — a human, a CI job, or an agentic SRE — writes an `Action` custom resource
describing *what* it wants and *why*. Baton is the only component with the RBAC to act on it.

The agent has no kubeconfig. That is the entire point.

```
  proposers                admission                 substrate
 ┌──────────┐            ┌───────────────┐         ┌─────────────┐
 │ triaged  │            │               │         │             │
 │ (agent)  ├──┐         │  Action CRD   │         │  Kubernetes │
 ├──────────┤  │ Action  │       +       │ apply   │   RKE2/OCI  │
 │ operator ├──┼────────►│ AutonomyPolicy├────────►│  workloads  │
 ├──────────┤  │         │       +       │         │             │
 │  human   ├──┘         │  Baton exec   │         │             │
 └──────────┘            └───────────────┘         └─────────────┘
                                 ▲
                          no path bypasses this
```

## Why this exists

"We let an LLM run `kubectl`" is a non-starter in any regulated environment. Baton splits the
problem: the **probabilistic** component (an agent) reasons about evidence and emits a proposal;
the **deterministic** component (Baton) validates it against policy, records it, and executes it.
Every mutation carries an audit trail with the evidence digests that justified it.

## Core objects

| Object | Purpose |
|---|---|
| `Action` | A proposed mutation: intent, operation class, target, evidence refs, proposer identity |
| `AutonomyPolicy` | Which proposer may auto-execute which operation class, in which namespaces, under what rate limits |

`Action.spec.intent` is a required field with a minimum length — the API server rejects an
unexplained proposal before Baton ever sees it. Evidence refs must be `sha256:`-digested, so a
proposal cannot cite a log line that no longer exists.

### Operation classes

Grouped by **blast radius**, not by verb — so a policy grants autonomy over a category of risk and
new verbs slot in without a policy rewrite.

| Class | Example | Typical autonomy |
|---|---|---|
| `Diagnostic` | exec a read-only probe | auto |
| `WorkloadLifecycle` | restart a deployment | auto |
| `WorkloadScale` | scale replicas within quota | auto |
| `ConfigMutation` | patch a ConfigMap | approval |
| `TrafficShift` | shift ingress weights | approval |
| `StorageMutation` | resize a PVC | approval |
| `SecretAccess` | read/rotate a secret | approval |
| `PolicyMutation` | change RBAC or Kyverno policy | manual |
| `NodeLifecycle` | cordon/drain a node | manual |
| `TenantLifecycle` | create/delete a tenant namespace | manual |

## Autonomy modes

Set per `(proposer, class, namespace)` tuple in an `AutonomyPolicy`. Nothing is hardcoded.

- `auto` — Baton executes immediately, records the Action, emits an event.
- `approval` — Action parks in `Pending`; a human approves via label or `kubectl baton approve`.
- `dryrun` — Baton runs the mutation with `--dry-run=server` and records the diff only.
- `deny` — rejected at admission with reason.

## Deployment modes

| Mode | Description |
|---|---|
| `standalone` | Baton alone. Proposers are humans and CI. |
| `paired` | Baton + `triaged` as separate deployments sharing the Action API. |
| `embedded` | Single binary, agent as a goroutine. Homelab / demo only. |

## Configuration

No values are baked into the binary. Everything is env or `--flag`, flags win.

| Env | Flag | Default | Meaning |
|---|---|---|---|
| `BATON_KUBECONFIG` | `--kubeconfig` | in-cluster | Cluster credentials |
| `BATON_NAMESPACE` | `--namespace` | `baton-system` | Where Baton watches for Actions |
| `BATON_WATCH_NAMESPACES` | `--watch-namespaces` | `""` (all) | Comma-separated allowlist |
| `BATON_MODE` | `--mode` | `standalone` | `standalone` \| `paired` \| `embedded` |
| `BATON_DEFAULT_AUTONOMY` | `--default-autonomy` | `deny` | Fallback when no policy matches |
| `BATON_DRY_RUN` | `--dry-run` | `true` | Global override; `--apply` to commit |
| `BATON_METRICS_ADDR` | `--metrics-addr` | `:8080` | Prometheus scrape endpoint |
| `BATON_LOG_FORMAT` | `--log-format` | `json` | `json` \| `text` |
| `BATON_AUDIT_SINK` | `--audit-sink` | `stdout` | `stdout` \| `elasticsearch` \| `file` |

**Dry-run is the default.** Committing requires an explicit `--apply`. This holds for the CLI, the
controller, and every script in `hack/`.

## Quickstart

```bash
make install          # CRDs into the current context
make run              # controller locally against that context (dry-run)
kubectl apply -f config/samples/autonomypolicy-conservative.yaml
kubectl apply -f config/samples/action-restart-deployment.yaml
kubectl get actions -A -o wide
```

## Supply chain

Every tagged release publishes a Syft SBOM and a keyless cosign signature. Verify before you run it:

```bash
cosign verify ghcr.io/jlawrence/baton:$TAG \
  --certificate-identity-regexp 'https://github.com/jlawrence/baton/.*' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Docs

- [ADR-0001 — The Action API as the sole mutation seam](docs/adr/0001-action-api-seam.md)
- [ADR-0002 — Operation classes by blast radius](docs/adr/0002-operation-class-taxonomy.md)
- [SECURITY.md](SECURITY.md)

## Related

- [`lode`](https://github.com/jlawrence/lode) — Rust log agent feeding the evidence store
- [`traffic-lab`](https://github.com/jlawrence/traffic-lab) — failure injection harness that exercises the Action path

## License

Apache-2.0
