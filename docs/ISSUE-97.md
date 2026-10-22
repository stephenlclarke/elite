# Issue #97: finish the native isolation work flow

## Actual evidence

Run `39793592000` at `7c1d4ac6` compiled in 862.64 seconds and completed 362 methods / 399 expanded cases without a process crash. There were 361 method passes and one failure: `nativeWorkNeedsActualPairAndFreshWriteBeforeLaterZeroFlowObservation` caught `invalidScene` after 170.511 seconds. The XML points to its declaration and does not identify a throw phase. The actual manual-combat/real-Tab/rollback method passed, closing #85, #96 and #98; #103 had already closed on actual compilation. #97 remains open for the complete positive flow.

## Source cause and correction

The fixture's actual Avenor launch creates and persists ordinary traffic. It then changed its system to Renas without the existing ordinary departure lifecycle. `NPCPersistenceLedger.resetPhysicalBindings(system:)` deliberately does nothing for a different system; it does not retire that Avenor ledger. The cold loader's `restoreSceneBindings` requires the ledger's system to equal the restored Renas system, explaining an inevitable invalid-scene condition in this fixture setup without attributing a phase from the empty XML.

Call the existing full `departOrdinarySimulation()` boundary while still in Avenor, before the fixture changes its system. Require the actual old ledger before departure, its retirement afterwards, and consistent new/cold scene systems. This remains a documented test scene, not a flown outbound journey. Preserve every production restoration guard, original source/programmer authority, 20-second work, both distinct verifications, cold restore, real return jump/doorway and receiving rollback/payment/clue assertion.

## Acceptance

Keep all 362 methods selected and retain the 361 actual passes honestly. The corrected full method and final head must pass the normal automatic workflow and independent review before #97 closes or PR #84 merges. No local runtime/native/probe campaign or production guard change is part of this fixture correction.
