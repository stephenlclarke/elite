# NPC resources and persistence handoff

This handoff supports [issue #18](https://github.com/stephenlclarke/elite/issues/18). The bounded source reconciliation on 17 October 2026 inspected frozen commit `34713f2577829be42d09d31c0b53bd1d500df3b9`. It found no additional proven behavior omission in the inspected paths. That source review does not qualify integrated acceptance or replace executed tests.

## Implemented behavior and focused acceptance coverage

| Acceptance | Maintained implementation | Authored focused coverage |
| --- | --- | --- |
| Actual shields, energy, heat, fuel, missiles and ECM; unknown legacy facts | `NPCResources.swift`, `NPCResourceRuntime.swift`, `GameplayCombat.swift` | `NPCResourceTests`: actual emitter thermal headroom, struck shield then hull, own recharge profile, legacy energy-only combat, accepted fuel consumption and actual solar scooping, spent-resource roundtrip |
| Actual manifests, routes and legal provenance; tier-gated compact panels | `NPCResourceRuntime.swift` (`telemetryFacts`), `TargetTelemetry.swift` | `NPCProducerFactsTests`: generated facts and pending-request replay; `NPCResourceTests`: compact panel reachability and actual facts disclosure; `TargetTelemetryTests`: tier gates, unknown readings and native cargo units |
| Ordinary identity and spent state across cull, dock, load and re-entry | `NPCPersistenceLedger.swift`, `NPCPersistenceRuntime.swift`, native save preparation in `Game.swift` | `NPCPersistenceRuntimeTests`: real save/load/launch, actual camera cull and restoration; `NPCPersistenceLedgerTests`: exact damage, consumables and pose, bounded admission and dock/new-visit preservation |
| Actual elapsed offscene movement, cooling and recharge | `NPCPersistenceRuntime.swift` (`advanceUnboundNPCs`) | `NPCPersistenceRuntimeTests.actualCullKeepsCoastingStateWithoutReAdmissionUntilPlayerReturns`: movement, cooldown, heat, unchanged fuel and restored spent state |
| Player, station and ordinary actor reference rebinding | `NPCPersistentReferences.swift`, `NPCPersistenceRuntime.swift` | `NPCReferenceRuntimeTests`: asymmetric re-entry batches, real save/load, terminal targets, player/station/foreign namespaces, refused admission retry, changed references and protected actor exclusion |
| Finite once-only death cargo and deferred capacity | `GameplayCargo.swift`, `NPCPersistenceLedger.swift`, death/cull/dock ordering in `Game.swift` | `GameplayCargoTests`: exact recorded manifest, native-unit scoop once, mission exclusion and destroyed pod custody; `NPCPersistenceRuntimeTests`: death before cull/dock, full debris ledger refusal, actual capacity recovery and exact cargo retry without resurrection |
| Failed writes, docking and escape preserve custody and old save bytes | Candidate save preparation in `Game.swift`, unsettled-death transition guards | `NPCPersistenceRuntimeTests.blockedCargoSettlementPreventsDockAndCameraRemovalUntilCapacityReturns`, `failedSaveCannotPublishNPCBindingsOrConsumeARecord`; `GameplayCargoTests.failedSavePublishesNeitherDeathSettlementNorChangedRuntime` |

Paths in the table are under `Sources/EliteCore` and `Tests/EliteCoreTests`. These are source mappings to authored tests, not a claim that the current integrated test lanes passed. The failed-save NPC test checks full Commander/body equality and exact previous file bytes before a successful retry. Deferred-death coverage retains the same incident through refused removal and transfers only the finite recorded manifest after actual capacity returns.

Actual NPC hyperspace actions and their fuel consumption remain outside this checkpoint. Offscene coasting does not invent AI actions, jump consumption or solar collection. Mission craft retain their explicitly separate legacy energy-only behavior.

## Historical checkpoint 094 and final delivery gates

This section retains the original checkpoint 094 handoff. Later exact-source results and outstanding release gates are recorded in the [current qualified ledger](WHOLE-APP-REMEDIATION.md). Coordinator run 094 on the frozen source failed in coverage. Reported failures include a nested campaign-trial stack overflow/SIGBUS and Cabin, combat, Gallery and help assertions. The run is nonpassing; it cannot qualify this handoff, and passing individual focused cases do not close the integrated gate. Repairs remain with their assigned integration owners.

Acceptance still requires `make ci` on the final integrated source, including coverage, both sanitizers and leak gates, and renderer-produced media from `make readme-media`. No build, test or renderer execution was performed for this document. Required final-head PR review and GitHub checks must complete before merge; main-only Sonar analysis must use the exact committed main SHA.

[NPC reference bindings](NPC-REFERENCE-BINDINGS.md) explains the relationship correction. [NPC-ACCEPTANCE-VALIDATION.json](NPC-ACCEPTANCE-VALIDATION.json) and [NPC-REFERENCE-ACCEPTANCE-VALIDATION.json](NPC-REFERENCE-ACCEPTANCE-VALIDATION.json) retain historical evidence for their recorded source commits. They do not qualify commit `34713f2`, run 094 or a later integrated head.

The GitHub issue's handoff link should target this file's repository URL after publication. A bare filename relative to an issue page does not resolve to the maintained `docs` directory. Adding this file alone does not update or close the issue.
