# traffic-lab

[![CI](https://github.com/jlawrence/traffic-lab/actions/workflows/ci.yml/badge.svg)](https://github.com/jlawrence/traffic-lab/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

**A failure-injection and load harness that makes a control plane prove it works.**

An observability stack that has never seen a real incident is a dashboard, not a control. An
autonomous remediation path that has never been triggered is an assertion, not a capability.
`traffic-lab` is how the rest of the Trinity platform earns those claims: it manufactures the
incident, and the platform either detects, proposes, and remediates it — or it doesn't, and you
find out on a Tuesday afternoon instead of at 3 a.m.

Two binaries:

- **`misbehave`** — a service that fails on demand. Error storms, latency injection, memory leaks,
  OOM, crashloops, PII-laden log floods, disk fill.
- **`loadgen`** — a closed-loop load generator that drives it, with configurable RPS profiles and
  latency histograms.

## Scenario → Action class map

Each scenario is designed to provoke a specific `Action` class in [`baton`](https://github.com/jlawrence/baton),
so the harness tests a *policy path*, not just a service.

| Scenario | Symptom | Expected detection | Expected Baton Action class |
|---|---|---|---|
| `error-storm` | 500s at N% of requests | `level:ERROR` rate spike in GEL | `WorkloadLifecycle` (restart) |
| `latency-creep` | p95 rises gradually | histogram p95 SLO burn | `WorkloadScale` |
| `memory-leak` | RSS grows monotonically | container memory trend | `WorkloadLifecycle` |
| `oom-kill` | container is OOMKilled | restart count + reason | `WorkloadScale` (raise limits) |
| `crashloop` | exits nonzero on start | CrashLoopBackOff | `ConfigMutation` (bad env) |
| `log-flood` | 50k lines/sec, some with fake PII | ingest lag + `lode_redactions_total` | `Diagnostic` |
| `disk-fill` | writes until the PVC is full | volume usage > threshold | `StorageMutation` |
| `dependency-timeout` | upstream call hangs | error budget burn | `TrafficShift` |
| `noisy-neighbor` | pins CPU, starves the namespace | throttling metrics | `WorkloadScale` |

Run the matrix, then assert on what Baton actually did:

```bash
kubectl get actions -A -o custom-columns=\
NAME:.metadata.name,CLASS:.spec.operation.class,MODE:.status.autonomyMode,PHASE:.status.phase
```

A scenario that produces **no** Action is as informative as one that produces the right one.

## The PII in `log-flood` is fake

`log-flood` emits synthetic records containing realistic-looking SSNs, emails, and bearer tokens
drawn from reserved test ranges. It exists to prove `lode`'s edge redaction actually fires. Nothing
in this repository contains, or should ever contain, real data.

## Configuration

Everything is flag- or env-driven, including the units. No values are compiled in.

### `misbehave`

| Env | Flag | Default | Meaning |
|---|---|---|---|
| `MISBEHAVE_ADDR` | `--addr` | `:8080` | Listen address |
| `MISBEHAVE_SCENARIO` | `--scenario` | `healthy` | Scenario name from the table above |
| `MISBEHAVE_ERROR_RATE` | `--error-rate` | `0.0` | Fraction of requests returning 5xx (`0.0`–`1.0`) |
| `MISBEHAVE_LATENCY_BASE` | `--latency-base` | `10ms` | Accepts `ms`/`s` |
| `MISBEHAVE_LATENCY_JITTER` | `--latency-jitter` | `5ms` | Added uniformly |
| `MISBEHAVE_LEAK_RATE` | `--leak-rate` | `0` | Bytes/sec retained; accepts `KiB`/`MiB` |
| `MISBEHAVE_LOG_RATE` | `--log-rate` | `10` | Lines/sec |
| `MISBEHAVE_LOG_PII` | `--log-pii` | `false` | Inject synthetic PII into log lines |
| `MISBEHAVE_LOG_FORMAT` | `--log-format` | `json` | `json` \| `text` |
| `MISBEHAVE_RAMP` | `--ramp` | `0s` | Ramp the fault in over this duration instead of stepping |
| `MISBEHAVE_METRICS_ADDR` | `--metrics-addr` | `:9090` | Prometheus endpoint |

### `loadgen`

| Env | Flag | Default | Meaning |
|---|---|---|---|
| `LOADGEN_TARGET` | `--target` | — | Required. Base URL |
| `LOADGEN_RPS` | `--rps` | `50` | Steady-state request rate |
| `LOADGEN_PROFILE` | `--profile` | `constant` | `constant` \| `ramp` \| `spike` \| `sawtooth` |
| `LOADGEN_DURATION` | `--duration` | `5m` | Accepts `s`/`m`/`h` |
| `LOADGEN_CONCURRENCY` | `--concurrency` | `16` | Bounded worker pool |
| `LOADGEN_TIMEOUT` | `--timeout` | `2s` | Per-request |
| `LOADGEN_LATENCY_UNIT` | `--latency-unit` | `ms` | `ns` \| `us` \| `ms` \| `s` — report units |
| `LOADGEN_OUTPUT` | `--output` | `text` | `text` \| `json` \| `prometheus` |
| `LOADGEN_METRICS_ADDR` | `--metrics-addr` | `:9091` | Prometheus endpoint |

## Run

```bash
# local
go run ./cmd/misbehave --scenario=error-storm --error-rate=0.3
go run ./cmd/loadgen   --target=http://localhost:8080 --rps=200 --profile=spike --duration=3m

# in-cluster
kubectl apply -f deploy/traffic-lab.yaml
kubectl -n traffic-lab set env deploy/misbehave MISBEHAVE_SCENARIO=log-flood MISBEHAVE_LOG_PII=true

# the whole matrix, dry-run first
./hack/run-matrix.sh              # prints what it would do
./hack/run-matrix.sh --apply      # actually runs it
```

Every script here is dry-run by default and requires `--apply` to touch a cluster.

## Dashboards

Grafana dashboards are code: `dashboards/*.json`, provisioned via ConfigMap in
`deploy/dashboards-configmap.yaml`. Export from Grafana and commit the JSON; don't hand-edit
in the UI and let it drift.

## Related

- [`baton`](https://github.com/jlawrence/baton) — the control plane whose policy paths this exercises
- [`lode`](https://github.com/jlawrence/lode) — the agent whose redaction path `log-flood` tests

## License

Apache-2.0
