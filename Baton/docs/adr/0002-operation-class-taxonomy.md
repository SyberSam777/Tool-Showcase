# ADR-0002 — Operation classes are grouped by blast radius, not by verb

**Status:** Accepted
**Date:** 2026-07

## Context

`AutonomyPolicy` needs a stable unit to grant autonomy over. The naive unit is the Kubernetes verb
plus resource (`patch deployments`). That leaks two ways: an operator writing policy has to reason
about verbs to understand risk, and every new remediation Baton learns forces a policy rewrite.

## Decision

Ten operation classes, ordered by how much damage a wrong call does:

`Diagnostic` → `WorkloadLifecycle` → `WorkloadScale` → `ConfigMutation` → `TrafficShift` →
`StorageMutation` → `SecretAccess` → `PolicyMutation` → `NodeLifecycle` → `TenantLifecycle`

Policy grants autonomy over classes. A new remediation is assigned to an existing class and
inherits its posture on day one.

## Consequences

- A compliance reviewer reads `class: SecretAccess → mode: approval` and understands it. They do
  not need to know what `patch secrets` implies.
- Classes cannot be added casually — an eleventh class means every existing policy has an implicit
  gap. The `defaultAutonomy: deny` fallback covers that safely.
- Misclassification is the main risk. Class assignment lives in Baton's code, not in the proposer's,
  so a compromised or confused agent cannot relabel a `TenantLifecycle` op as `Diagnostic`.
