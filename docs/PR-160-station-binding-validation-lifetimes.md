# Validate full station state before reserving binding lookup temporaries

## Motivation

[Issue160](https://github.com/stephenlclarke/elite/issues/160) identifies a current mapped stack-guard fault at station body validation entry in the original physical evasion test.

## Implementation

Keep all body/physical/world-presence checks and complete native station validation in a noninline entry. Borrow the same captured world into a private noninline binding helper retaining original record, system, tombstone, energy, physical visit and binding guards in exact order. No authority predicate is removed or replaced by a shallow header.

## Validation

Formatting and diff hygiene pass. The original authentic station entry and in-place mesh/refusal methods share the159 five-method focused packet, preferring the existing pinned release compiler when idle. Actual-source/result review and execution are pending. [The issue evidence](ISSUE-160-station-binding-validation-lifetimes.md) records exact image/fault and above-guard SP distinction.

## Compatibility and remaining limits

No save, schema, identity, mutation, actor isolation, test selection or quality gate changes. No automatic old-issue reopening or signal attribution. Full current VM/quality, completed-save/reopen qualification and release remain separate.
