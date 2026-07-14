# ADR-0001 — Scenarios are defined by the Action class they should provoke

**Status:** Accepted
**Date:** 2026-07

## Context

A load/chaos harness normally tests *the service*: does it survive 10k RPS, does it recover from an
OOM. That is not the interesting question here. The interesting question is whether the **control
plane** notices, proposes the right thing, and is permitted to do it.

## Decision

Every scenario is specified as a triple:

```
(fault injected, signal it should produce in GEL, Action class Baton should emit)
```

The scenario is a *pass* only when the expected Action appears with the expected class and the
expected `status.autonomyMode` for the policy under test. The service's own behaviour under load is
incidental.

## Consequences

- The harness tests the **policy**, not just the code. Running the matrix against a conservative
  `AutonomyPolicy` and then a permissive one should produce different `autonomyMode` values for the
  same faults — that difference is the real assertion.
- A scenario producing *no* Action is a finding: either a detection gap in GEL or a reasoning gap in
  triaged. Silence is a test result.
- Adding a Baton operation class means adding a scenario that provokes it, or that class ships
  untested. This is enforced by convention, not tooling — a gap worth closing.
- Coupling: traffic-lab now depends on Baton's class taxonomy. Acceptable; the taxonomy is versioned
  with the `v1alpha1` API and changes rarely by design.
