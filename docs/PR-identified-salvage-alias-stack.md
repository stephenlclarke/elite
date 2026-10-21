# fix(game): borrow state for identified salvage aliases

identifiedSalvageAlias now has a thin non-inlined wrapper that rejects missing mission/logical markers and unsupported hull/position/orientation before heavier access. It copies only the small SpaceBody for closure compatibility, projects the source optional and instances COW dictionary through existing withReadOnlyScriptState, projects the current SystemIdentity and delegates through withReadOnlyCommander to a private non-inlined kernel. The complete original kernel guard/body and alias ordering remain after only three read substitutions. Small source values and existing ScriptInstance COW remain; no whole Commander/ScriptEngineState copy or storage architecture change is introduced.

Only the alias wrapper/private kernel in NativeIdentifiedSalvageRecovery.swift, an appended boundary regression in its RecoveryTests and these paired notes change. All other recovery code and original tests remain unchanged. Game, AsteroidDebrisContact, recorder, controller, G3/G12 and MC1 paths are untouched. No stack/concurrency/timeout waiver, diagnostic change, new framework or user-facing feature is included.

## Regression and matching owner selection

The new actualAliasReaderKeepsBothOriginalsAndCradleAuthorityAndRejectsUnprovedBodies method uses real acceptance and the actual Renas admitted scene. It requires pell-cradle, pell-01 and pell-02 aliases; for every actor it rejects source revocation and six unmarked/foreign mission/logical/spawn/visit/retained-ID variants. Returned strings are projected before test macros. It does not weaken existing authority, frame, custody, save or journey assertions.

G1's exact focused selection is seven methods/20cases:

- NativeIdentifiedSalvageRecoveryTests.actualAliasReaderKeepsBothOriginalsAndCradleAuthorityAndRejectsUnprovedBodies: one new boundary case.
- NativeIdentifiedSalvageRecoveryTests.actualEmptyInertiaFrameCapturesPackageAndCradleMeshMassWithoutDebrisFlags: one existing actual-frame case.
- NativeIdentifiedSalvageRecoveryTests.actualOtherMissionSameModelKeepsExistingCollisionPolicy: one existing unrelated-mission case.
- NativeIdentifiedSalvageRecoveryTests.consumedOriginalStaysExcludedThroughActualVisitAndColdRebinding: one existing consumed/cold case.
- NativeIdentifiedSalvageJourneyTests.actualTwoOriginalJourneyReservesOnceAndPaysOnlyAtSameOwner: one existing actual native journey.
- NativeIdentifiedSalvageSaveTests.independentlyGenuine51And52PreserveEachCustodyBoundary: eight existing alien false/true by allocated/one/received/hull-loss cases.
- stationAutoOffensiveRefusalKeepsNativeInventoryAndEmissionState: all seven clean/protected/occluded/unjoined/idle-hostile/disabled-source/energy conditions. The actual failed condition remains unknown; none is omitted or guessed.

Source parse/format/strict lint, normalized original guard/body preservation, appended-test isolation, unchanged shared/producer/journey/save files, paired Markdown and diff checks pass. Native compilation and all20cases are pending with G1; the author runs no native compiler, test, symbolication, debugger, probe or CI job. Causal compiler/unit corrections precede one complete independent bugs/performance/style review of the passing four-path freeze. Source inspection and similarity to the qualified recorder correction do not prove exact frame allocation, this reader's native qualification or hosted repair. See [the observed blocker](ISSUE-identified-salvage-alias-stack.md).
