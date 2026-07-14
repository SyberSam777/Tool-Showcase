# Contributing

## Ground rules

1. **No hardcoded values.** Anything an operator might reasonably want to change is an env var or a
   flag, with the flag winning. This includes namespaces, intervals, thresholds, endpoints, and
   units.
2. **Dry-run by default.** Any code path or script that mutates state defaults to a no-op and
   requires an explicit `--apply`.
3. **New operation classes need an ADR.** See `docs/adr/0002`.
4. **API changes to `v1alpha1` need a conversion story** before they merge.

## Local development

```bash
make generate manifests
make install
make run
make test
make lint
```
## Commits

Conventional Commits (`feat:`, `fix:`, `docs:`, `refactor:`, `chore:`). Signed commits preferred.
