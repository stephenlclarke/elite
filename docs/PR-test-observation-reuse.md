# Reuse published runtime-test observations

This combines only the exclusive test/helper changes from [PR216](https://github.com/stephenlclarke/elite/pull/216) (`2aaa0325`) and [PR217](https://github.com/stephenlclarke/elite/pull/217) (`3129537d`) onto actual canonical `e5914e24008c53f334bd7f82062db8ccfa76a30d`. The inherited M03 changes are omitted. The three affected Swift files match the already-authored postimages exactly; only this paired documentation is new.

In the multi-batch test, the first and resumed work loops pass the fresh-press decision from their last published frame to an additive helper overload. The original overload still takes its own snapshot and forwards the same decision. The conditional control sequence and real actor advance are unchanged. The sequential caller must not mutate actor input/state between observing that decision and advancing. All three work phases retain their preceding scalar observation; the observation helper borrows its Game input. No shared Game cache or new loop is introduced.

In the measured-extraction fixture, the hold and extraction loops inspect the Game returned by `runtime.advance` instead of discarding it and immediately requesting another snapshot. Hold readiness and exact-root depletion predicates remain the same. Final readiness, extraction, recovery, save/reload and authority/custody checks are unchanged.

## Preserved behavior and local evidence

All 77 multi-batch and 139 measured-extraction complete assertion calls remain byte-identical and in the same order. The three 2500-frame bounds with 0.02-second steps and the 400/1000-frame bounds with 0.05-second steps remain. Cases, controls, exit predicates, work budgets and actual save/authentication/custody checks are retained. The original opt-in continuation diagnostic keeps its existing enablement and snapshot-taking path; this packet does not change or enable it.

Strict affected Swift formatting, scoped Markdown and whitespace checks pass. Source-only checks bind each Swift postimage to its original exclusive commit, compare all ordered assertion calls, and verify the helper's conditional control/advance tail and loop bounds/deltas. No compiler, test, native, profiling or standalone execution ran. Existing isolated fleet passes do not qualify these runtime methods. No production, shared schema, selector, workflow, sanitizer, timeout or current M01 source changes are included.

## Exact execution handoff

Root routes these existing methods and all their declared parameter cases through the next already-required candidate checkpoint. Do not dispatch a separate baseline or native run while the current M01 campaign is active. The fourteen primary affected method IDs are:

- `NativeMultiBatchRuntimeTests.originalHumanManifestImportRequiresAFullSecondBudgetAcrossActualSaveAndReload`
- `NativeMeasuredExtractionJourneyTests.actualNaturalMiningTwelveOriginalScoopsProcessingAndSeparateReceiverPaysOnce`
- `NativeMeasuredExtractionJourneyTests.departureExpiresUncollectedOriginalsAndPartialSurvivorsRequireUnpaidSourceReturn`
- `NativeMeasuredExtractionJourneyTests.actualAutomaticRecoveryCollectsTwelveOriginalsAndCompletesSeparateReception`
- `NativeMeasuredExtractionAcquisitionTests.exactNativeOriginalStillRequiresCurrentSafeCollector`
- `NativeMeasuredExtractionAcquisitionTests.refusedWriterRetainsActualNativeAttemptAndRetryConsumesItOnce`
- `NativeMeasuredExtractionAcquisitionTests.actualHullOrEscapeLossReleasesOnlyHeldOriginalsAndNeverAwardsSuccess`
- `NativeMeasuredExtractionAcquisitionTests.nativeStationWriterRefusalKeepsActualInputsOutputsAndMoneyUntilRetry`
- `NativeMeasuredExtractionAcquisitionTests.actualMiningWithoutSelectedPermissionOrOrdinaryBreakupCannotMintExtraction`
- `NativeMeasuredExtractionAcquisitionTests.actualOreDestructionFailsJobWhereasNativeCullOnlyReleasesBinding`
- `NativeMeasuredExtractionSaveTests.genuine55And56ColdReloadPreservesEachNativeBoundary`
- `NativeMeasuredExtractionSaveTests.genuineW05G09G10PermissionsComposeUnderOwnEnvelopeWithoutFabricatedHistory`
- `NativeMeasuredExtractionSaveTests.normalizedPositiveSaveAndRehashedMutationRefuseBrokenOwnProvenance`
- `NativeMeasuredExtractionSaveTests.actualMovingOriginalIntakePreservesIssuedIdentityAndAmount`

The original snapshot-taking helper also forwards through the new overload. These existing compatibility consumers retain their setup, controls and assertions; use meaningful coverage within that same required candidate checkpoint rather than a separate replay campaign:

- `NativeSalvageOfferTests.actualNativeOfferRequiresExactCurrentContextSourceAndWholeRequest`
- `NativeSalvageOfferTests.nativeOfferStagingRejectsStaleSourceAndUnallocatedNamespaceWithoutMutation`
- `NativeSalvageAdmissionRuntimeTests.genuineNativeReleaseAdmitsOnlyActualSafeActorsAndMovesThemInItsReleaseFrame`
- `NativeSalvageAdmissionRuntimeTests.nativeOfferCannotBypassExactParentProtectionMeshPlayerOrOtherActorChecks`
- `NativeSalvageAdmissionRuntimeTests.refusedNativePlacementDiscardsPrivateOfferAndPreservesEveryReleasedLot`
- `NativeSalvageAdmissionRuntimeTests.fullActualCargoPopulationLeavesOriginalNativeCustodyAndAllocatorUntouched`
- `NativeSalvageAdmissionRuntimeTests.nativeSectionNeverFallsBackToAnOriginalOrdinaryOffer`
- `NativePagedSalvageRuntimeTests.genuineGeneratedInspectionAndWorkBypassEveryFullOrdinaryLifetimePool`
- `NativePagedSalvageRuntimeTests.actualActorWriterRefusalRetainsCompletedBudgetAndRetryMovesReleasedFragmentsInTheSameFrame`

`NativeSalvageAdmissionTestFixture.released` uses its existing shared original setup and `makeReleased` helper. No sharing policy or cache is added or changed. `NativeMultiBatchRuntimeTests.retained542SecondCycleContinuationDiagnostic` retains its original private-source/environment opt-in and is not a new required run for this packet.

## Timing and remaining gates

The prior source note for PR216 at `2aaa0325` records 2426.7 seconds for `NativeMultiBatchRuntimeTests.originalHumanManifestImportRequiresAFullSecondBudgetAcrossActualSaveAndReload`. Its execution-lane fingerprint is not specified in that note. Reuse the owner's already-retained matching-lane timing metadata at the next candidate comparison; never compare normal and ASAN/TSAN timings as equivalent baselines. Do not rerun the old baseline. The measured-extraction source note has no numeric baseline.

A speedup remains unmeasured. Independent source review and the actual scoped candidate results remain pending, so this packet is not integration-ready merely because source checks pass. Retain PR216/217 and issues219/220 as historical evidence until Root reconciles the combined delivery. Main, current M01 execution, native/release results and playable completion are separate. [Motivation and acceptance](ISSUE-test-observation-reuse.md).
