# Separate request preparation and typed transit validation phases

## Change

Base is exact run-659 canonical source `ba70799f8688d82bda53902a1bd21c0483c1ed1c`. The two changed Swift files follow the matched request/native-save/typed-leg validation spine. There are no writer, reader, Game, regex, schema, world or unrelated fixture changes.

The fixture's non-inlined `prepareRequest` performs the original mission/actor selection, destination search and actual native transit request. It returns only the actor UUID. Those retained values and search captures retire before the unchanged native writer runs. The outer method still computes and returns the same leg identity after writing, in its original order. No failed write is swallowed or retried.

`NativeWormholeLeg.valid` now completes a non-inlined request-fields phase before its non-inlined receipt/phase validation. Every original identifier, route, scalar, calendar, spool, opening, exact creator/address, fuel, fitted body, due-time, arrival and phase check retains its order and condition. `ScriptEngineState.nativeWormholeStateValid` validates the typed ledger before a separate non-inlined owner/history phase retains its mission, actor, departure and history traversal values. Latest-arrival location and duplicate-time rejection remain exact. No rule is weakened to make the requested-only path pass.

## Preservation and validation

Inverse phase extraction reproduces both complete base Swift files byte-for-byte, removing only the extraction wrappers and their separator. Proof is `/tmp/elite-native-transit-request-phase-source-proof.json`. Strict Swift formatting/lint, scoped Markdown lint and whitespace checks pass. The exact crashed test file remains unchanged. Its original method exercises actual request publication, unavailable-world pending behavior, unchanged source/fuel, no opening/departure, stable repeated identity, pure query/Commander equality and no transit-clock addition. The existing cohort creator-address and latest-arrival corruption regressions also remain unchanged.

No author compiler, build, test, CI, native, GUI, debugger, profiler or ABI job runs. No stack/concurrency/work-budget change, test skip, cached validation result, alternate save path, new boxed simulation state or trusted receipt is introduced. Source lifetime separation does not establish measured frame sizes, stack margin, performance or a runtime fix. Central G1 must compile and execute the exact crashed method and affected transit/current-format save cases. Preserve the interrupted 659 evidence and the still-UNKNOWN original 655/657 outcomes until their matching methods complete. Required final matching-head CI/review/check/merge gates remain separate. See the [issue](ISSUE-native-transit-request-validation-lifetime.md).
