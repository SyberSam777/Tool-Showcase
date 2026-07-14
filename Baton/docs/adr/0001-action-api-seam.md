# ADR-0001 — The Action API is the sole mutation seam

**Status:** Accepted
**Date:** 2026-07

## Context

Trinity includes `triaged`, an agentic SRE that correlates logs and metrics and reaches conclusions
about what is wrong. The obvious implementation is to give it a kubeconfig and let it act. In any
environment with a compliance auditor, that is unshippable: a non-deterministic component holding
mutate RBAC has an unbounded blast radius and no reviewable decision record.

## Decision

`triaged` gets **no cluster credentials**. It gets create/read on one CRD: `Action`.

Baton is the only component with mutate RBAC on the substrate. It watches `Action` objects,
evaluates each against the matching `AutonomyPolicy`, and either executes, parks for approval,
server-dry-runs, or denies. The three-tier flow is:

```
proposer ──Action──► admission (Baton + AutonomyPolicy) ──apply──► substrate
```

There is deliberately **no edge** from proposer to substrate.

## Consequences

**Good**
- The agent is swappable. A different model, or a human, or a CronJob, are all just proposers.
- Every mutation has an `intent` string and `sha256:`-pinned evidence refs. The audit record is a
  side effect of the design, not a bolt-on.
- Autonomy is a policy decision, not a code change. Tightening it is a YAML edit.
- Baton is independently useful with zero AI in the picture.

**Bad**
- Latency: a proposal round-trips through the API server before anything happens. Acceptable —
  remediation is not on a hot path.
- Two components to operate instead of one. Mitigated by the `embedded` deployment mode.
- The `Action` schema is now a compatibility surface. Versioned as `v1alpha1` accordingly.

## Alternatives rejected

- **Agent with scoped RBAC.** Still couples the agent's reasoning to its authority, and the scope
  has to be widened for every new remediation. The audit trail is Kubernetes audit logs with no
  intent attached.
- **Agent calls a REST API on Baton.** Works, but loses declarative storage, `kubectl` ergonomics,
  RBAC on the proposal itself, and the ability for a human to `kubectl apply` a proposal by hand.
