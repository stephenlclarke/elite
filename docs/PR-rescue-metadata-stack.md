# fix(game): borrow stored commander during rescue classification

originalRescueFacts now lends Game's stored Commander through existing withReadOnlyCommander and delegates to a private non-inlined reader with explicit borrowing Commander, body, encounter context and bodies parameters. The wrapper projects the bodies array before the closure so the closure needs no Game capture. The complete original guard sequence, order, nested authority checks, uniqueness test, person/record distinction and fits calculation remain unchanged. The existing small metadata constructor gains a non-inlined boundary and still constructs metadata solely from validated facts. No new storage or framework is introduced.

This targets the actual captured ___chkstk_darwin rescue-metadata fault path. Exact optimized frame sizes and successful native repair are not established by source inspection. WorkTargetRuntime, AutoTargetControl and all G09 owner files remain unchanged, along with the existing command/default suite, actor isolation, stack size, concurrency, timeout and gate settings.

## Regression coverage and selected owner qualification

The existing genuine classifier test now checks the complete independently expected occupied-pod, mission-protected metadata, including bounds and empty work surfaces. All six retained dead, foreign, empty, replaced-body-ID, missing-NPC and EMP tamper cases must reject both facts and metadata. Existing native-pod separation and unchanged custody/EMP assertions remain. Facts and metadata are projected before test macros.

A new ordinary-flight regression uses the existing paid G03 preparation, actual launch and physical-actor admission for a controlled ordinary Cobra. It proves no rescue state, nil rescue facts/metadata and a live, front-visible normal ship candidate with the actual physical identity. It does not fabricate a rescue marker or bypass rescue authority. The exact crashing station-auto method and genuine native Tab rescue-collection method remain byte-for-byte unchanged.

G1's matching owner selection is four nonparameterized methods/four cases:

- stationAutoConfirmedMilitaryResponsePreemptsRetainedActor
- NativeOriginalRescueCapsuleTests.rescueClassifierRejectsDeadForeignEmptyAndReplacedActorsWithoutEMPPersonImpersonation
- NativeOriginalRescueCapsuleTests.rescueMetadataLeavesOrdinaryNativeFlightShipSelectableWithoutRescueState
- NativeOriginalRescueCapsuleTests.rescueActualTabGuidanceCollectsTheRegisteredOriginalCapsule

Owner compilation and execution are pending. The author performs only source parse/format, semantic-preservation, Markdown and diff checks, with no native build, test, reproducer, debugger or CI run. G1 qualifies the matching frozen source when available; causal compiler or unit corrections come first. One independent bugs/performance/style review of the passing freeze precedes integration. The next normal required full CI must establish whether the hosted fault is repaired; no current global pass or release completion is claimed.

See [the observed release blocker](ISSUE-rescue-metadata-stack.md).
