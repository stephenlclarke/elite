# Separate six patrol verification phases from fixture admission

## Change

Six synchronous tests retain their original `patrolGame` call and pass the returned game by inout reference to a private verification helper. Each helper contains the entire original post-fixture remainder in its original order. The native completion test also keeps its original pack read before the fixture and passes that same pack onward. See [the captured evidence and selected callers](ISSUE-script-encounter-fixture-lifetimes.md).

## Preservation and compatibility

All original physical commands, inputs, ticks, actor identities, measured contacts, fresh attack origins, real laser impacts, death/bounty counters, dock/relaunch sequences, rollback and whole-world/Commander assertions remain. The factory, asynchronous tests, raw-save paths and remaining synchronous callers are unchanged. Only test helper boundaries change; no production code, case selection, runtime flag, heap wrapper or skip changes.

## Validation and remaining risk

Independent inverse inlining reconstructs the entire original `ScriptEncounterTests.swift` byte for byte at source `f0f90e24b2ec616058926d2c9de34471ca9f928f`. Strict Swift/Markdown lint and diff checks pass. Combined focused 214 passed all six changed existing methods and five runtime consumers on `3ef104f2450b420b3dfe5de076fc551d62ac2be8`, including the actual 212 fatal-hit caller in 9.443 seconds. Proof `/tmp/elite-focused-batch-214/agent-game-test-verification-214.json` verifies protected inputs and process closure. This focused pass is not full-suite acceptance or original 211 crash equivalence.

The independent actual-214 emitted audit confirms each wrapper now reserves only its one required local Game and no Commander-sized SP buffer during fixture admission. Old Game/Commander counts were fatal hit 4/1, foreign events 3/0, native completion 1/1, missing station 3/0, physical-save consistency 2/2 and new-Commander isolation 1/2. Each later verification helper is called after the unchanged factory returns; its own verification storage still exists. Audit `/tmp/elite-g2-frame-phases-214-offline-audit/measurement.json`, SHA256 `14752d483ed0895c5221deb961b7a1f54f6b252aef0fbd6ce3af0a4733575280`, with exact binary `51f9df2a675eae7c0cd53cd91b14b43f306a996d7fae991237634f00681f86ff`. Counts describe named emitted reservations, not total stack or peak memory. Required composed `make ci` remains pending.
