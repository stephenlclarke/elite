# fix(game): borrow state for recorder alias validation

The non-inlined recordRecoveryAlias wrapper rejects missing mission/logical markers and unsupported hull/position/orientation before heavier reads. It copies only the small SpaceBody for closure compatibility, projects the source optional and instances COW dictionary through existing withReadOnlyScriptState, projects the equivalent current SystemIdentity and delegates through withReadOnlyCommander to a private non-inlined kernel. The source optional is a small value projection; no whole Commander or ScriptEngineState is copied into the kernel. Existing ScriptInstance COW/storage remains unchanged.

The kernel retains the complete original guard sequence and alias iteration order. The only data-access substitutions are the source optional, projected instances and equivalent system scalar; original body/source/owner/dock/definition/mission/visit/spawn/fit/models/consumed/custody/capture/loss/reception checks and exact alias/nil semantics remain. Cheap eligibility remains in the kernel as well as the wrapper. No return shortcut grants authority from markers alone.

Only WayfarerRecordRecoveryAcquisition.swift, an appended AcquisitionTests boundary regression and these notes change. Game, AsteroidDebrisContact, WorkTargetRuntime, AutoTargetControl and G3/G12/MC1 sources stay unchanged. No architecture, framework, diagnostic hook, actor isolation, stack limit, concurrency, timeout or gameplay-policy change is introduced.

## Regression and matching owner qualification

The appended actualAliasReaderKeepsCradleAndOriginalAuthorityAndRejectsUnmarkedOrForgedBodies method uses the actual accepted/Celalen mission fixture. It checks genuine cradle and cdr-001 aliases, rejects unmarked/foreign-mission/logical/spawn/visit/retained-body-ID copies, and rejects both genuine actors after source authority is removed. Alias values are projected before test macros. Existing acquisition and actual station-auto producer methods stay unchanged.

G1's exact focused selection is five nonparameterized methods/five cases:

- stationAutoDefensiveAttitudeKeepsStationProgressAndOneCombinedThrustBudget: unchanged actual symbolicated fault producer, ordinary auto-target path with no W05 source/markers.
- WayfarerRecordRecoveryAcquisitionTests.exactNativeFrameUsesRecorderAndCradleMeshMassAndRejectsUnprovedEndpoint: unchanged genuine mesh/mass/frame and revoked-authority behavior.
- WayfarerRecordRecoveryAcquisitionTests.unrelatedMissionSameModelRetainsItsExistingCollisionPolicy: unchanged unrelated mission/mesh authority.
- WayfarerRecordRecoveryAcquisitionTests.realIdentificationLeavesRecorderAtCradleAndCannotCollectInItsFrame: unchanged native identification/collection and same-frame refusal.
- WayfarerRecordRecoveryAcquisitionTests.actualAliasReaderKeepsCradleAndOriginalAuthorityAndRejectsUnmarkedOrForgedBodies: appended direct reader boundary.

Source parse/format/strict lint, original normalized guard/body preservation, appended-test isolation, producer/shared-file preservation, paired Markdown and diff checks pass. Native compilation and all five cases are pending with G1. No author native build, test, debugger, symbolication, probe or CI run occurs. Real compiler/unit corrections precede one complete independent bugs/performance/style review of the passing freeze; integration and normal required hosted CI follow only when qualified. Source structure alone does not establish stack savings or a hosted crash repair. See [the actual reader fault and uncertainty](ISSUE-record-alias-stack.md).
