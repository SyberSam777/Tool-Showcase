# lode

[![CI](https://github.com/jlawrence/lode/actions/workflows/ci.yml/badge.svg)](https://github.com/jlawrence/lode/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

**A Rust log-shipping agent for Kubernetes that redacts at the edge, not at the index.**

`lode` runs as a DaemonSet, tails container logs off the node, normalizes and redacts them, and
ships them to Elasticsearch. It is a `FROM scratch` static musl binary — no shell, no package
manager, no interpreter, nothing for an attacker to pivot into.

It is the `L` in **GEL** (Grafana → Elasticsearch → **lode**), the observability tier of the
Trinity platform, and it is the only Trinity component that stands entirely on its own.

## Why not Filebeat / Fluent Bit / Vector

Mostly you should use one of those. `lode` exists because of one design difference worth having:

**Redaction happens before the log leaves the node.** In a Filebeat-style pipeline, PII is written
to disk, read, sent over the wire, and scrubbed by an ingest pipeline — by which point it has
existed in three places you now have to reason about. `lode` applies the redaction ruleset in the
tailer, so a record containing an SSN never leaves the kubelet's node with the SSN intact. In a
regulated environment that is the difference between a control and a hope.

Secondary reasons: single ~5 MB static binary, no JVM, no plugin surface, ~15 MB RSS per node.

## Pipeline

```
/var/log/containers/*.log
        │  tail + inode-stable checkpointing
        ▼
   [ parse ]     CRI-O / containerd / docker-json / raw, auto-detected
        │
        ▼
   [ enrich ]    pod, namespace, container, node, labels from the kubelet API
        │
        ▼
   [ redact ]    regex + entropy rulesets, applied in-process, before egress
        │
        ▼
   [ batch ]     bounded queue, backpressure, exponential-backoff retry
        │
        ▼
   Elasticsearch bulk API  →  index `lode-*`  →  Grafana ES datasource
```

## Configuration

Layered: built-in defaults → config file → environment → CLI flags. Later wins. Nothing is
hardcoded, including the units.

| Env | Flag | Default | Meaning |
|---|---|---|---|
| `LODE_CONFIG` | `--config` | `/etc/lode/lode.yaml` | Config file path |
| `LODE_LOG_DIR` | `--log-dir` | `/var/log/containers` | Where to tail from |
| `LODE_CHECKPOINT_DIR` | `--checkpoint-dir` | `/var/lib/lode` | Offset persistence |
| `LODE_PARSER` | `--parser` | `auto` | `auto` \| `cri` \| `docker` \| `raw` |
| `LODE_OUTPUT` | `--output` | `elasticsearch` | `elasticsearch` \| `stdout` \| `file` |
| `LODE_ES_URL` | `--es-url` | — | Required when output is `elasticsearch` |
| `LODE_ES_INDEX_PREFIX` | `--es-index-prefix` | `lode` | Index becomes `<prefix>-<date>` |
| `LODE_ES_USER` / `LODE_ES_PASS` | — | — | Read from Secret; never from the config file |
| `LODE_BATCH_SIZE` | `--batch-size` | `512` | Records per bulk request |
| `LODE_BATCH_BYTES` | `--batch-bytes` | `4MiB` | Accepts `KiB`/`MiB`/`GiB` or raw bytes |
| `LODE_FLUSH_INTERVAL` | `--flush-interval` | `5s` | Accepts `ms`/`s`/`m` |
| `LODE_QUEUE_DEPTH` | `--queue-depth` | `8192` | Bounded; blocks the tailer when full |
| `LODE_RETRY_MAX` | `--retry-max` | `8` | Exponential backoff, jittered |
| `LODE_REDACT_RULES` | `--redact-rules` | `/etc/lode/redact.yaml` | Ruleset path |
| `LODE_REDACT_MODE` | `--redact-mode` | `mask` | `mask` \| `hash` \| `drop` |
| `LODE_METRICS_ADDR` | `--metrics-addr` | `0.0.0.0:9600` | Prometheus endpoint |
| `LODE_LOG_LEVEL` | `--log-level` | `info` | lode's own logging |

Durations and sizes are parsed with units, never assumed. `5s`, `500ms`, `4MiB` all work.

### Redaction rules

```yaml
# /etc/lode/redact.yaml — mounted from a ConfigMap
version: 1
mode: mask                # global default; per-rule override below
rules:
  - name: ssn
    pattern: '\b\d{3}-\d{2}-\d{4}\b'
    mode: drop            # this record never ships at all
  - name: email
    pattern: '[\w.+-]+@[\w-]+\.[\w.]+'
    mode: hash            # sha256, stable across records, so you can still correlate
  - name: bearer-token
    pattern: '(?i)bearer\s+[A-Za-z0-9._-]{20,}'
    mode: mask            # -> "bearer ****"
  - name: high-entropy
    entropy:
      min_bits: 4.2
      min_len: 24
    mode: mask
```

## Deploy

```bash
kubectl apply -f deploy/namespace.yaml
kubectl create configmap lode-redact --from-file=redact.yaml -n observability
kubectl apply -f deploy/daemonset.yaml
```

### SELinux note (RHEL / RKE2)

Reading `/var/log/containers` (`container_log_t`) and writing checkpoints
(`container_var_lib_t`) both trip AVC denials under enforcing SELinux. The DaemonSet ships with:

```yaml
securityContext:
  seLinuxOptions:
    type: spc_t
```

That is the deliberate, documented trade: `spc_t` is a super-privileged container type. If your
policy forbids it, the alternative is a custom SELinux module granting only those two transitions —
`deploy/selinux/lode.te` has it.

## Metrics

`lode_records_read_total`, `lode_records_shipped_total`, `lode_records_dropped_total{reason}`,
`lode_redactions_total{rule}`, `lode_queue_depth`, `lode_bulk_latency_seconds`,
`lode_bulk_errors_total{code}`. Scrape config in `deploy/servicemonitor.yaml`.

## Known limitation

Elasticsearch field-mapping collisions: an app logging `user` as a string and another logging it as
an object will conflict in a shared index. Currently handled with an index template setting
`ignore_malformed: true`, which tolerates the collision but silently drops the offending field.
The proper fix — promoting parsed JSON fields under a `fields.*` namespace so they can never
collide with top-level metadata — is tracked in [#roadmap](docs/ROADMAP.md).

## Related

- [`baton`](https://github.com/jlawrence/baton) — control plane that consumes lode's output as Action evidence
- [`traffic-lab`](https://github.com/jlawrence/traffic-lab) — generates the log floods and PII leaks that exercise the redaction path

## License

Apache-2.0
