# Reuse validation only for an identical complete station world

## Problem and resulting behavior

Repeated complete checks of the station registry delayed actual flight and docking fixtures in validation 311. Each `NativeStationWorld` now holds one private derived validation witness protected by `OSAllocatedUnfairLock`. Its immutable payload contains all nine semantic world fields, including the complete ledger, poses, observations and receipts. Swift copy-on-write storage preserves independent snapshots. The witness has no world, game, commander or callback reference and retains no history.

A hit requires complete semantic equality. A miss executes the unchanged original full predicate before recording a successful value. Failed checks do not create a witness. Concurrent snapshots may replace the single witness but cannot authenticate different values. Neither coding keys nor semantic equality include the derived lock/witness; decoded worlds start with an empty witness and execute the same full checks. Station-condition persistence also avoids assigning an identical energy value, retaining shared array storage while still publishing every real condition change.

## Validation

Five new regression methods cover changed canonical poses and owners, actor rebinding, tombstone/energy joins, foreign docking custody, valid damage, main observations and receipt highwater, unchanged JSON and whole-world equality, forged decoded witness data, and concurrent independent copied values. The next focused run retains the four unfinished original physical methods with their original iterations and deltas, plus the new methods and relevant source/save/ownership regressions. The original 600-second limit and default concurrency remain unchanged.

Source review and focused execution are pending. No performance improvement is claimed yet. Validation 311 remains an honest timeout with 23 completed passing methods; those results are retained and the unchanged 27-method group is not blindly rerun. Its artifact proof is `/tmp/elite-native-station-structure-focused-311/agent-timeout-verification-311.json`.

## Compatibility and remaining acceptance

No source identities, geometry, game rules, coding fields or save schema change. Source parsing, strict formatting, scoped Markdown lint and whitespace checks passed. A byte-for-byte body comparison confirms that the original complete validation predicate is unchanged. Actual corrected compact/fullscreen visual capture, coherent full CI and coverage, Address Sanitizer, leak checks, renderer media, completed clean GitHub review, protected merge, main-only SonarQube and distribution validation remain outstanding.

## Link

[ISSUE-native-station-validation.md](ISSUE-native-station-validation.md).
