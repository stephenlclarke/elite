# MBA-04: preserve W01 medical sample integrity against the native flight timer

## Motivation

W01 l337.wayfarer-service/cold-chain needs a finite authored medical-sample allowance that survives pause and save/load without a second clock or spend bank. Bind owner, instance, consignment and receiver to the existing one-shot flight timer. Never infer flight time from courier mission-calendar proof clocks.

## Scope and acceptance

Add only WayfarerColdChain.swift, focused unit sources and these paired notes. Calculate remaining integrity from the original native timer due minus the latest admitted absolute flight clock. Repeated snapshots preserve state; reject reversed flight clocks/revisions, changed timers and foreign bindings. Reception before the due boundary and the existing native timer.fired event each permit at most one descriptive terminal result.

## Validation

Eleven focused Swift tests are AUTHORED UNRUN. They use actual ScriptTimer, ScriptEventContext, ScriptEvent and ScriptCourierTerminalReceipt types without constructing Game or running simulation. MBA execution is restricted to source/Python work; G1 owns native compilation, focused test execution and make ci.

## Compatibility and linked work

Current-format schema 1 only; no legacy save migration is provided. No existing production files or persisted commander schema are changed. Linked handoff: PR-wayfarer-cold-chain.md; ledger MBA-04, milestone M09, F33/K08/K09. No GitHub issue or PR exists for this packet.

## Remaining risk and completion boundary

MBA-05 must derive snapshots from actual live native clock/timer state, validate owner and active instance, current custody, exact consignment and receiver resource, and the admitted native reception/timer event. It must verify saved bindings against those authorities on load, preserve the original timer, and atomically publish the terminal result with existing durable custody/reception authority. These structs and serialized receipts describe facts; they are not action capabilities. This source-only model is not a playable W01 completion.

## Focused execution correction

Local lease 748 executed all 19 selected methods: 18 passed, including all eight bonded-freight methods, and delayedTimerDispatchUsesExistingAbsoluteClock failed on integer-valued timer-event JSON roundtrip equality. Timer expiry now persists a closed typed projection of the already admitted native event (sequence, instance, timer identity, due, fired-at and context), retaining the original native-event admission and binding checks. This avoids ScriptValue number/integer normalization changing saved descriptive equality. Whole-number and fractional dispatch times and corrupted saved receipt identity/due/time/sequence are covered in the existing focused methods. No new clock, schema version or action authority is added. G2 semantic re-review and focused rerun remain pending. Swift formatting and Markdownlint pass on the owned source and notes.
