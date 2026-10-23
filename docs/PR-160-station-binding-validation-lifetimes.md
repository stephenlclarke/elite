# Validate full station state before reserving binding lookup temporaries

## Motivation

[Issue160](https://github.com/stephenlclarke/elite/issues/160) identifies a current mapped stack-guard fault at station body validation entry in the original physical evasion test.

## Implementation

Keep all body/physical/world-presence checks and complete native station validation in a noninline entry. Borrow the same captured world into a private noninline binding helper retaining original record, system, tombstone, energy, physical visit and binding guards in exact order. No authority predicate is removed or replaced by a shallow header.

## Validation

Formatting, diff hygiene and independent actual-source review pass. The first combined five-method execution at `ec83d6f8` used the existing Swift6.1.2/SDK15.5 release VM. Compilation passed in305.13seconds; the process exited1 with raw signal10 after318.266985833seconds. Both fleet policy methods passed (10.489seconds each), as did the in-place station mesh/refusal method (10.549seconds). Original delayed-report and authentic station-entry methods started but have no terminal result. Fleet policy methods exercise ledger policy, not the observer directly. Retained `/tmp/elite-159-160-focused.log` and `-result.json` record the failed process; the Swift Testing XML remains an unfinished52-byte document. Fault attribution and affected-path qualification remain pending. [The issue evidence](ISSUE-160-station-binding-validation-lifetimes.md) records exact image/fault and above-guard SP distinction.

## Compatibility and remaining limits

No save, schema, identity, mutation, actor isolation, test selection or quality gate changes. No automatic old-issue reopening or signal attribution. Full current VM/quality, completed-save/reopen qualification and release remain separate.

## Retained two-method follow-up execution

The unchanged original delayed-report and authentic station-entry methods ran at `be90e52c` after the actual credit phase correction. Swift6.1.2/SDK15.5 compilation passed in84.87seconds; the process exited1 with raw signal10 after96.9157105seconds. Both methods started only, with no terminal pass or assertion result; XML remains unfinished. Retained `/tmp/elite-159-credit-focused.log`, `-result.json`, `-crash.ips` and `-image.json` preserve the failed result and exact loaded imageF7EA4912-63A1-38CB-BDEB-61834779E2D1/SHA256b558042848839159e4477d94de2de650276eb28b29a82c8a93671e623add34ac. Attribution remains pending. The three earlier unaffected `ec83d6f8` individual passes are retained separately; no aggregate qualification is claimed.

## Combined checkpoint result

The source-reviewed combined159-168 packet `eb5ab2d8` compiled successfully, then its one normal four-original-method batch failed signal10/exit1 after198.327703625seconds with zero completed methods/assertions. No matching normal report exists; the separate exact-image capture is diagnostic only. No issue is closed or runtime-qualified by source review. [The combined packet inventory](PR-25-M01-RELEASE-BLOCKERS.md) records exact source, evidence limits, retained unaffected passes and remaining required gates.
