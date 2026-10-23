# Bound fleet destruction observer eligibility before publication

## Motivation

[Issue159](https://github.com/stephenlclarke/elite/issues/159) identifies an owned fleet observer stack path in the original delayed native completion-report test; no normal guard mapping is available.

## Implementation

A thin noninline entry preserves death, player ownership and body-target checks before a private noninline helper runs the exact body/catalogue eligibility and publication. Existing typed storage readers supply unchanged optional equipment owner and flight time. Keep all evidence fields, full fleet authority and original read order. Reflow only the existing formatter-rejected catch comment without changing its text or logic.

## Validation

Formatting and diff hygiene pass. Original delayed-report timing plus positive/negative fleet policy methods run alongside the two directly affected160 station methods in one coherent build. Actual-source/result review and focused execution are pending. See [the issue evidence](ISSUE-159-fleet-destruction-observer-lifetimes.md).

## Compatibility and remaining limits

No game/save representation, actor boundary, authority, reward, test selector or quality gate changes. No historical144 or prior issue recurrence is assumed. Full VM/quality, completed-save/reopen proof, signing and release remain separate.
