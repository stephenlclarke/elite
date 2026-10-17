# Reuse validation only for an identical complete station world

## Problem and resulting behavior

Repeated complete checks of the station registry delayed actual flight and docking fixtures in validation 311. Each `NativeStationWorld` now holds one private derived validation witness protected by `OSAllocatedUnfairLock`. Its immutable payload contains all nine semantic world fields, including the complete ledger, poses, observations and receipts. Swift copy-on-write storage preserves independent snapshots. The witness has no world, game, commander or callback reference and retains no history.

A hit requires complete semantic equality. A miss executes the unchanged original full predicate before recording a successful value. Failed checks do not create a witness. Concurrent snapshots may replace the single witness but cannot authenticate different values. Neither coding keys nor semantic equality include the derived lock/witness; decoded worlds start with an empty witness and execute the same full checks. Station-condition persistence also avoids assigning an identical energy value, retaining shared array storage while still publishing every real condition change.

## Validation

Five new regression methods cover changed canonical poses and owners, actor rebinding, tombstone/energy joins, foreign docking custody, valid damage, main observations and receipt highwater, unchanged JSON and whole-world equality, forged decoded witness data, and concurrent independent copied values. The next focused run retains the four unfinished original physical methods with their original iterations and deltas, plus the new methods and relevant source/save/ownership regressions. The original 600-second limit and default concurrency remain unchanged.

Source review approved the frozen implementation and the unchanged full predicate. Validation 312 passed all 13 selected methods (19 expanded cases) under Thread Sanitizer and default concurrency in 267.315 seconds including a 53.30-second compilation. All four previously unfinished physical methods completed with their original iterations and time steps. All 2008 tracked inputs, protected user files and owned-process exit identities were independently verified. The proof is `/tmp/elite-native-station-validation-focused-312/agent-game-test-verification-312.json`. No native performance improvement is claimed by this focused test result. Validation 311 remains an honest timeout with 23 completed passing methods; those results are retained and the unchanged 27-method group is not blindly rerun. Its artifact proof is `/tmp/elite-native-station-structure-focused-311/agent-timeout-verification-311.json`.

## Compatibility and remaining acceptance

No source identities, geometry, game rules, coding fields or save schema change. Source parsing, strict formatting, scoped Markdown lint and whitespace checks passed. A byte-for-byte body comparison confirms that the original complete validation predicate is unchanged. Validation 313 completed one corrected native compact/fullscreen capture under the original scene, path, seed and diagnostic protocol. All 1425 compact and 1418 fullscreen station observations had consistent rendered/canonical poses and clear resolved hull sweeps, with full player energy/shields. The actual images were inspected for continuous exterior panels and the intact open bore/arms. All 2008 tracked inputs, protected user files and 18 owned process identities, including both actual staged applications, were verified. The proof is `/tmp/elite-native-station-corrected-313/agent-native-corrected-verification-313.json`. Candidate p95 drawn-frame intervals were 19.73025 ms compact and 19.843292 ms fullscreen; maxima were 42.024042 and 96.217291 ms. This is a candidate measurement, not a claim of universal 60 Hz or a measured before/after improvement. Coherent full CI and coverage, Address Sanitizer, leak checks, renderer media, completed clean GitHub review, protected merge, main-only SonarQube and distribution validation remain outstanding.

## Link

[ISSUE-native-station-validation.md](ISSUE-native-station-validation.md).
