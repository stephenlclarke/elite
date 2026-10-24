# Reuse the measured-extraction actor's published frame

Two loops in `NativeMeasuredExtractionJourneyTests.swift` now inspect the Game returned by `runtime.advance` instead of discarding it and immediately requesting another snapshot. The hold loop still checks `workGuidance.holding`; the extraction loop still checks depletion of the exact original root. Each actual advance, input command, frame limit, delta, break predicate, required work budget and assertion remains.

The returned frame is local to one iteration. There is no new cache or helper API. Final readiness, extraction, custody, save/reload and authority checks remain unchanged. No production or execution-gate change is included.

## Validation and remaining evidence

Strict Swift formatting, whitespace and Markdown checks pass. A source comparison confirms every complete assertion call remains byte-identical and in the same order; the two predicate receivers alone change. No local build, test, profiling or benchmark ran. Removing the duplicate publication is an implementation fact; measured duration and a speedup remain unproved.

Root routes matching affected execution and MBA source/result review through the existing authorized owner. The maintained isolated selection covers extraction domain methods, not these journey helpers; unrelated isolated passes cannot qualify this packet. The exact consumer methods are:

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

This source packet is separate from the multi-batch packet and frozen M03 identities. M01 merge hold remains. Implementation/validation is pending until affected execution and independent review are complete. See [the issue note](ISSUE-measured-extraction-test-overhead.md).
