# test(persistence): align canonical save fixture baselines

## Changes

The contract-trial isolation baseline now follows the first successful live save. Explicit `KEEP`, 7654 native cash units (765.4 CR) and original live-cargo checks protect the save barrier itself. Trial resources, foreign-quote rejection, isolated trial save/load, the entire normalized live commander and exact live file bytes remain checked. Awaited snapshots and throwing reads are bound before assertions, apart from the intentional expected-throw closure.

Successful game-over reset and retry now require the exact fresh `ScriptEngineState` containing only `ScriptCalendarLedger(origin: .newCommander)`, canonical durability, valid cleared mission state, default name/credits, zero cargo and a new equipment owner. They require a new schema-26 commander-scope pointer/generation, strict `ScriptSaveStore.read`, whole saved/reset equality and actual runtime reload equality. The failed-publication path retains all original native-state, nine-control-value, original-save-byte and parsed prior-save assertions; the successful retry also checks cleared controls. No raw decoder fallback is introduced.

## Scope and validation

Exactly three existing methods and three cases change across `ScriptContractTests.swift` and `ScriptTransactionTests.swift`, with one pure expected-state helper and this issue/PR pair. All production code and other test methods remain unchanged. The parent is `901f75fc58412b7a6caf5d63e4010b4cf59e0f4f`. The frozen contact producer and its separate bus-fixture child are preserved on their original refs and are excluded from this stability leaf.

Source formatter/parser, strict scoped lint, Markdownlint and diff/scope/hash checks are the only local verification. No compiler, typecheck, discovery, test, native/GUI/build/media or GitHub job is run. The original 328 run remains failed; the retry case is included because of its directly shared source expectation, without claiming it executed in 328. Root must review this test-only leaf before G1 composes it with its separately owned stack correction and runs the planned bounded batch/full gates. Source checks do not establish execution success. Eventual PRs retain completed clean `@codex review` cycles, final-head checks, required independent approval and protected merge without bypass.
