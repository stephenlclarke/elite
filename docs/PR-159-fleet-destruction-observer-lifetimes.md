# Bound fleet destruction observer eligibility before publication

## Motivation

[Issue159](https://github.com/stephenlclarke/elite/issues/159) identifies an owned fleet observer stack path in the original delayed native completion-report test; no normal guard mapping is available.

## Implementation

A thin noninline entry preserves death, player ownership and body-target checks before a private noninline helper runs the exact body/catalogue eligibility and publication. Existing typed storage readers supply unchanged optional equipment owner and flight time. Keep all evidence fields, full fleet authority and original read order. Reflow only the existing formatter-rejected catch comment without changing its text or logic.

## Validation

Formatting, diff hygiene and independent actual-source review pass. The first combined five-method execution at `ec83d6f8` used the existing Swift6.1.2/SDK15.5 release VM. Compilation passed in305.13seconds; the process exited1 with raw signal10 after318.266985833seconds. Both fleet policy methods passed (10.489seconds each), as did the in-place station mesh/refusal method (10.549seconds). Original delayed-report and authentic station-entry methods started but have no terminal result. Fleet policy methods exercise ledger policy, not the observer directly. Retained `/tmp/elite-159-160-focused.log` and `-result.json` record the failed process; the Swift Testing XML remains an unfinished52-byte document. Fault attribution and affected-path qualification remain pending. See [the issue evidence](ISSUE-159-fleet-destruction-observer-lifetimes.md).

## Compatibility and remaining limits

No game/save representation, actor boundary, authority, reward, test selector or quality gate changes. No historical144 or prior issue recurrence is assumed. Full VM/quality, completed-save/reopen proof, signing and release remain separate.

## Same-path combat credit follow-up

The first combined `ec83d6f8` execution passed both fleet ledger policy methods and in-place station mesh, but the delayed-report and authentic entry methods did not finish. The matched normal report for PID35199 (launch20:24:55.1898, capture20:25:06.3479UTC) identifies `creditCombatDeath` after the observer call, with fault0x16d2c7ff8 inside guard0x16d2c4000-0x16d2c8000 and SP0x16d2c8080 above it. Loaded imageB8819958-FF05-36F5-BC72-5C184BAEDE7A matches the collected binary SHA256e7b333699c9870e962a26edb655f8ad3e6592197ea2993c13188bd8322426441. Retained `/tmp/elite-159-160-focused-crash.ips` and `-image.json` establish this distinct stop in the same159 combat call chain; no historical144 cause is inferred.

A noninline eligibility entry preserves optional death, player ownership, body target and body lookup, target-ship, Glass Meridian clock and C01 surveyor exclusions. Only after eligibility does a private noninline helper run unchanged previous-rank capture, wrapped kill increment, wrapped bounty credit and final rank notification. Reward policy and read/mutation order remain unchanged. Retain the three unaffected individual passes from `ec83d6f8`; the next execution runs only the two incomplete original delayed-report and authentic-entry methods using the existing release-toolchain cache. These are separate source/result receipts, not a synthetic five-method aggregate. The complete original oracles still require passing execution.
