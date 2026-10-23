# Validate full station state before reserving binding lookup temporaries

## Motivation

[Issue160](https://github.com/stephenlclarke/elite/issues/160) identifies a current mapped stack-guard fault at station body validation entry in the original physical evasion test.

## Implementation

Keep all body/physical/world-presence checks and complete native station validation in a noninline entry. Borrow the same captured world into a private noninline binding helper retaining original record, system, tombstone, energy, physical visit and binding guards in exact order. No authority predicate is removed or replaced by a shallow header.

## Validation

Formatting, diff hygiene and independent actual-source review pass. The first combined five-method execution at `ec83d6f8` used the existing Swift6.1.2/SDK15.5 release VM. Compilation passed in305.13seconds; the process exited1 with raw signal10 after318.266985833seconds. Both fleet policy methods passed (10.489seconds each), as did the in-place station mesh/refusal method (10.549seconds). Original delayed-report and authentic station-entry methods started but have no terminal result. Fleet policy methods exercise ledger policy, not the observer directly. Retained `/tmp/elite-159-160-focused.log` and `-result.json` record the failed process; the Swift Testing XML remains an unfinished52-byte document. Fault attribution and affected-path qualification remain pending. [The issue evidence](ISSUE-160-station-binding-validation-lifetimes.md) records exact image/fault and above-guard SP distinction.

## Compatibility and remaining limits

No save, schema, identity, mutation, actor isolation, test selection or quality gate changes. No automatic old-issue reopening or signal attribution. Full current VM/quality, completed-save/reopen qualification and release remain separate.
