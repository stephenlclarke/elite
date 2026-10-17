# Separate six patrol verification phases from fixture admission

## Change

Six synchronous tests retain their original `patrolGame` call and pass the returned game by inout reference to a private verification helper. Each helper contains the entire original post-fixture remainder in its original order. The native completion test also keeps its original pack read before the fixture and passes that same pack onward. See [the captured evidence and selected callers](ISSUE-script-encounter-fixture-lifetimes.md).

## Preservation and compatibility

All original physical commands, inputs, ticks, actor identities, measured contacts, fresh attack origins, real laser impacts, death/bounty counters, dock/relaunch sequences, rollback and whole-world/Commander assertions remain. The factory, asynchronous tests, raw-save paths and remaining synchronous callers are unchanged. Only test helper boundaries change; no production code, case selection, runtime flag, heap wrapper or skip changes.

## Validation and remaining risk

Independent inverse inlining reconstructs the entire original `ScriptEncounterTests.swift` byte for byte at source `f0f90e24b2ec616058926d2c9de34471ca9f928f`. Strict Swift/Markdown lint and diff checks pass. This worker has not compiled or executed the changes. The integration owner retains focused execution, any new emitted comparison and required composed `make ci`; no crash resolution or full-suite acceptance is claimed.
