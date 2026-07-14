# ADR-0001 — Redact at the node, not at the index

**Status:** Accepted
**Date:** 2026-07

## Context

The standard Kubernetes logging pipeline (Filebeat/Fluent Bit → Elasticsearch ingest pipeline)
scrubs sensitive data *at ingest*. By the time an ingest processor masks an SSN, that SSN has been
written to the node's disk, read by the agent, buffered in memory, and transmitted over the network.
Three copies exist that a control has to account for, and any of them can be captured by a node
compromise, a pcap, or a misrouted output sink.

## Decision

Redaction runs in the tailer, in-process, before the record is queued for egress. A record matching
a `drop`-mode rule never enters the batch buffer at all.

## Consequences

**Good**
- The claim "PII does not leave the node" is a control an auditor can verify by reading one config
  file, not an emergent property of a five-hop pipeline.
- The redaction ruleset is a single versioned artifact (`redact.yaml`), not split between the agent
  and the ES cluster.
- A compromised Elasticsearch does not expose data that was never sent to it.

**Bad**
- CPU cost moves to every node instead of centralizing on the ES ingest nodes. Measured at ~3% of
  one core at 5k records/sec per node with 12 rules — acceptable, but it *is* a per-node tax.
- The raw record is now unrecoverable. If a rule is too aggressive, the data is gone; there is no
  re-index that gets it back. This is intentional and the trade must be understood before writing a
  `drop` rule.
- Regex on rendered lines is coarse and false-positive-prone. Structured, field-targeted redaction
  is the planned successor (see ROADMAP #3) and depends on field-namespacing landing first.
