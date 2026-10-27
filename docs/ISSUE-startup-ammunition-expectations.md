# Verify current startup equipment migration

The startup regression helper still expected version-one equipment with four standard foundations and no acquisition history. The current migration also preserves the legacy finite missile count as version-two physical ammunition with legacy provenance and matching entitlement records. The existing full-run failures are obsolete assertions, not evidence of lost startup state.

Require the actual version-two representation, unchanged finite missile count, one physical round per occupied pylon, legacy provenance and exact round/entitlement identity joins. Retain four standard foundations, empty paid history, complete non-equipment JSON comparison, corrupt/missing-file rollback and no-overwrite assertions.

See [the implementation](PR-startup-ammunition-expectations.md). Focused validation and full CI remain required.
