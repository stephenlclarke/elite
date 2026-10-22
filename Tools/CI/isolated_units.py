#!/usr/bin/env python3
"""Run the maintained isolated-unit selection and reject empty/incomplete reports."""

from __future__ import annotations

import json
import os
from pathlib import Path
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

from crash_artifacts import runtime_child_environment
from isolated_crash_evidence import IsolatedCrashEvidence

ROOT = Path(__file__).resolve().parents[2]
METHODS = {
    "NativeStationSnapshotUnitTests": (
        "exactSnapshotRejectsEveryStoredFieldChangeAndDuplicateOrAbsentBodies",
        "authenticEntryAttackStillUsesMountedGunPhysicalEvasionAndOneBudget",
    ),
    "NativeWayfarerInductionAccreditationUnitTests": (
        "owningTerminalRecordsExactly7600OnceChosenCharterAccreditationAndOneUniqueClue",
        "repeatedSennConfirmationCannotPayOrGrantAnotherClueOrDiscardExistingBookings",
        "actualUncollectedCancellationAfterAccreditationReturnsSameStockWindowAndKeepsFinalReceipt",
        "realHeldSeedReceivingAfterSennPaysOnlyItsFrozenQuoteAndRetainsTheOwningEntitlement",
        "revisionOnlyForgeryMissingChildAcknowledgementOrClueCannotPreserveAccreditation",
        "wrongOwningSourceOperationRewardAndOriginalProofCannotBecomeACompletionClue",
        "terminalFormatsCloseTheNativeProofAndKeepEarlierSchemasAndUnknownRefusalsDistinct",
        "finalHelpAndOrdinaryServicePathsKeepTheirExistingLimitsAndNoPrematureEntitlement",
    ),
    "NativeWayfarerInductionNetworkUnitTests": (
        "veilCertifiesOnlyTheOriginalNetworkOnceWithoutPaymentOrChangingAnyCustody",
        "signaturesAndLaterConsignmentsCannotReplaceTheActualSelectedCharterAudit",
        "rehashedWrongOriginalProofStationClockOrSequenceStillCannotCertify",
        "certificationRequiresItsOwnActualAcknowledgementClockContactAndEarlierChildJoins",
        "certificationHasClosedNewFormatsAndCannotEnterEarlierEmbeddedOrUnknownArchives",
        "laterOwnerWindowReleasePreservesCertifiedProofsAndContextHelpKeepsSennSeparate",
    ),
    "NativeWayfarerInductionCharterAuditUnitTests": (
        "bothSelectedPoliciesRefuseRealOriginalCandidateWithoutChangingAnyStockOrWindow",
        "missingRealSourceOrSignaturesAndOwnerStationQuotesCannotAdvanceTheCharter",
        "protectedOwnerReleaseInvalidatesStaleConfirmButPreservesEarlierActualAudit",
        "forgedProtectedBoundaryOwnerPolicyClockOrUnchangedFingerprintCannotBecomeAnAudit",
        "allThreeRealDelegatedSourcesRemainEligibleWithoutBypassingThreeActiveContracts",
        "actualAuditSaveRequiresItsOwnAcknowledgementNativeClockAndHistoricalAvenorContact",
        "closedAuditFormatsRejectEarlierEmbeddedUnknownAndMisplacedClaimsWhileRetainingOldSources",
        "auditHelpAndReadOnlyProjectionDoNotCreateRemotePickupOrPrematureCertification",
    ),
    "NativeWayfarerInductionSeedUnitTests": (
        "sixOriginalThreeTonneLotsAreDistinctFromClinicWorkshopInductionAndGenericW03Stock",
        "currentReachableEnlirinLareriaQuoteUsesExactWholeItineraryPriceAndCannotRelabelGenericSeed",
        "bookingUsesThirdSharedSlotAndSameOwnerWindowAndPickupSwapsExactlyThreeRealTonnes",
        "actualOriginalReceivingPaysFrozenQuoteOnceAndReturnsOnlyItsWindowWithoutParentProgress",
        "beforePickupCancellationReturnsSameWarehouseLotWindowAndThreeTonnesWithoutStartingTimer",
        "heldCancellationRetainsOriginalCargoWindowAndDeadlineUntilActualOwnerReturnWithoutFreshStock",
        "exactNativeExpiryKeepsOriginalQualityProofAndUsesCurrentPublicationForTheWindowReturn",
        "actualCarrierLossAndUncollectedSourceDestructionNeverRestockOrPayForLostLots",
        "pauseAndColdRestoreKeepSameOriginalLotAndAbsolute7200SecondIntegrityWithoutRefill",
        "sourceStockChildWindowAcknowledgementAndNativeClockClaimsMustJoinBothDirections",
        "otherOwnerUpdatesKeepAllThreeSourcesAndAvenorReadonlyCannotBecomeRemotePickup",
        "changedLotTermsOrStaleCashCannotPartiallyReceiveReleaseCargoOrCreateSeedPayment",
        "contextualSeedRowsAndCapturedQuoteKeepPickupReceivingReturnAndHelpSeparate",
        "closedSeedSchemaPreservesEarlierOperatorsAndRejectsEarlyEmbeddedUnknownOrOrphanClaims",
    ),
    "ContextControlHintUnitTests": (
        "systemScrollHintsFollowActualViewportAndHelpReturnContext",
        "inventoryPagingHintsDisappearWhenAllRowsFitAndRetainSharedFlightControls",
    ),
    "AlienMissileServiceUnitTests": (
        "nativeArtefactResearchPaysOnceConsumesOriginalAndCreatesOneStoredPrototype",
        "researchedPlughSupplyChargesDiscountedPriceAndSharesFinitePylons",
        "loadedPrototypeLaunchConsumesExactItemAndUsesAlienProfileAndMesh",
        "failedResearchWriterAndStaleServiceRetainSourceCashAndPrototypeCount",
        "coldCurrentSaveRetainsResearchAfterPrototypeConsumptionAndRejectsForgedPayment",
        "standardUnlimitedLaunchNeverFabricatesAlienRoundsOrSpendsLoadedOriginal",
    ),
    "AlienHyperspaceDriveUnitTests": (
        "alienOnlyLootProducesTypedDriveWithoutScalarUpgradeOrOrdinaryFit",
        "forgedDriveEvidenceAndReplayCannotCreateOwnedCapability",
        "pagedDriveCustodyRoundTripKeepsIdentityAndOtherHullIsolation",
        "actualRecoveryAndPlughFittingSurviveColdSaveAndJumpImmediatelyThroughMassLock",
        "storingDriveRevokesCapabilityAndStaleOrUndockedRefitDoesNothing",
        "fittedAlienDriveRetainsFuelElectricalAndOrdinaryDriveGates",
    ),
    "NativeIsolationProgrammerUnitTests": (
        "actualCanonicalLoanOccupiesOneTonneAndReturnRemovesOnlyTheOriginal",
        "fullRealHoldRefusesBeforeCreatingProgrammerOrObligation",
        "matchingLabelForeignSerialOrChangedSourceCannotSupplyOriginalCustody",
        "acquisitionOnlyDefinitionHasNoFittingOrShopOffer",
    ),
    "WantedDossierNameUnitTests": (
        "recordedPlughLocationsAndDestinationsKeepTheirGalaxyAndName",
        "ordinaryAndUnknownReportsRetainHistoricalWordingWithoutChangingProperty",
    ),
    "MarketDisplayOrderUnitTests": (
        "authoredOrderKeepsEachStableCommodityIDAndCargoIndex",
        "arrowSelectionFollowsAuthoredOrderWithoutTradingOrChangingModes",
        "renderedRowsAndClicksUseTheSameStableIDsAtCompactAndWideSizes",
    ),
    "NativeWayfarerInductionWorkshopUnitTests": (
        "originalBatchKeepsSixDistinctFailedSerialsSeparateFromClinicCargoAndAllWindows",
        "wholeReachableOutAndReturnItinerarySetsExactFrozenPriceWithoutGenericW03Weakening",
        "nativeBookingReservesSameOwnerWindowAndTwoRealTonnesBeforeUntimedPickup",
        "actualRenasServiceKeepsSameSerialAndConditionAndOnlyOriginalOwnerReturnPaysOnce",
        "cancellationBeforePickupReturnsUnchangedWarehouseSerialWindowAndSpaceWithoutPayment",
        "heldCancellationRetainsActualFailedOrServicedConditionUntilOwnerReturnAndNeverRestocks",
        "carrierExitAndKnownSourceLossPreserveWarehouseOrLostOriginalTruthWithoutCash",
        "reverseStockWindowAcknowledgementAndCapturedReadonlyScopeCannotInventNativeCustody",
        "contextualBoardAndPinnedInternalFamilyKeepOriginalOperationsSeparateWithoutLoadGrants",
        "changedSerialConditionOrStaleCashCannotRepairClonePayOrPartiallyReturnOriginal",
        "closedWorkshopSchemaPreservesEarlierClinicAndRejectsEarlyEmbeddedUnknownOrOrphanClaims",
    ),
    "NativeWayfarerInductionClinicCustodyUnitTests": (
        "pickupReplacesReservedTonneWithSameOriginalCargoAndStartsOnlyItsAbsoluteFlightDeadline",
        "pauseAndColdRestoreKeepOriginalSerialQualityTimerAndRemainingAllowance",
        "receivingPaysFrozenQuoteOnceAndClosesOriginalWindowCargoAndNativeReceiptWithoutStageTwelve",
        "heldCancellationKeepsCargoWindowAndDeadlineUntilActualOwnerReturnWithoutReissueOrCash",
        "nativeExpiryRequiresExactOriginalQueuedEventAndPreservesItsProofAcrossLaterPublication",
        "attainedCarrierLossFailsHeldOriginalWithoutPayingRestockingOrBorrowingAWindow",
        "alteredPickupTimerCargoAndMissingCompletionCannotClaimOriginalCustody",
        "contextualBoardKeepsPickupReceivingAndHeldReturnSeparateWithoutChangingCustody",
        "staleCashOrAlteredEndCannotPartiallyPayReleaseStockOrConsumeOriginalCargo",
        "closedCustodySchemaPreservesEarlierBookingsAndRejectsEarlyEmbeddedUnknownAndGenericClaims",
    ),
    "NativeWayfarerInductionClinicAcceptanceUnitTests": (
        "acceptanceReservesSameOriginalSampleOwnerWindowAndOneRealTonneWithoutPickupOrProgress",
        "cancellationReturnsSameWarehouseSampleAndWindowOnceAndRequiresFreshProtectedRelease",
        "uncollectedCarrierLossReleasesUnchangedWarehouseStockButDestroyedSourceNeverRestocks",
        "stockHistoryCannotReorderRepeatReuseOldInstanceOrInventHeldSerials",
        "saveJoinsRequireOriginalChildAcknowledgementsClockAndExactStockWindowReceipt",
        "globalThreeContractLimitAndActualCargoFitIncludeUncollectedClinicBookings",
        "laterOperatorConsentUsesActualHistoricalReservationClockWithoutDroppingClinicState",
        "bookingWindowUsesOnlyClinicOwnerAndRefusesDelegatedReadOnlyScope",
        "changedSourceUnitOwnerOfferPriceAndCarrierCannotKeepAcceptedAuthority",
        "closedAcceptanceSchemaRejectsEarlierEmbeddedUnknownOrUnpairedNativeClaims",
    ),
    "NativeWayfarerInductionClinicSourceUnitTests": (
        "originalClinicBatchUsesSixNewOperatorStockSerialsSeparateFromWindowsAndInductionCargo",
        "currentReachableOriginalRoutesSetExactLegPriceAndIntegrityWithoutForcedJumpOrFuel",
        "readOnlyAvenorDelegationCannotBecomeRemotePickupOrQuoteForeignUnits",
        "laterOwnerConsentAndExactUnitReleaseKeepTheSameOriginalClinicStockAndRefreshOnlyQuoteIdentity",
        "originalSourceDecodeRejectsMissingRefilledHeldOrForeignStockAndDoesNotRecreateUnits",
        "owningSourceClaimsRequireActualAcknowledgedIssueStationAndClockAndRefusePrematureConsignments",
        "exactInternalFamilyPinsSourceAndRemainsOutsideGenericAcceptanceGalleryAndStockInitialization",
        "sourceDetailUsesTheCapturedReadOnlyQuoteWithoutReplanningFromTheRenderPath",
        "closedClinicSourceSchemaRejectsEarlyEmbeddedUnknownDelegationAndGenericInstanceClaims",
    ),
    "NativeWayfarerInductionCharterConsentUnitTests": (
        "threeDistinctActualOwnerConsentReceiptsBindEachSelectedBranchWithoutReleaseOrStageTwelve",
        "ownerConsentRefusesWrongStationChangedEpochMinimaUnitsRevisionAndDuplicateOrOtherBranch",
        "separatelySignedNamedFreeUnitReleasePreservesHistoricalConsentAndAllProtectedCapacity",
        "nativeReleaseSaveNeedsSameActualSignatureAcknowledgementStationHistoryAndClock",
        "protectedBoardShowsDistinctExactUnitKeysAndReadOnlyReviewsCannotReleaseOrCreateStock",
        "closedConsentSchemaRejectsEarlierEmbeddedAndUnknownSignatureOrUnsignedReleaseClaims",
    ),
    "NativeWayfarerInductionCapacityUnitTests": (
        "originalCapacityHasEighteenDistinctOwnerEpochUnitsAndSixProtectedWithoutChangingStage",
        "pooledBookingsExhaustOnlyTwelveFreeSurplusUnitsAndNeverBorrowProtectedMinimum",
        "protectedCapacityNeedsExactOwnerReleaseAtItsOwnStationAndCannotDoubleRelease",
        "completionOrCancellationReturnsSameUnitToOriginalOwnerAndPolicyWithoutReusingConsignment",
        "staleForeignQuotesAndReorderedOrDuplicatePolicyEventsCannotConsumeCapacity",
        "nativeSourceClaimsNeedActualOwningAcknowledgedAllocationAndCannotSavePolicyOnlyBookings",
        "closedCapacitySchemaKeepsEarlierChoicesAndRejectsEarlyEmbeddedUnknownAndRefilledClaims",
    ),
    "NativeWayfarerInductionUtilityBindingUnitTests": (
        "sameVisitFreshNativeBindingRetainsLogicalModuleHistoricalPartialWorkAndSingleKit",
        "bindingProducerRefusesForeignRoleAddressOrRetainedAliasAndArmCannotChangeItsProof",
        "closedBindingSchemaRejectsOldEnvelopesAndPreservesUnboundHistoricalArms",
    ),
    "NativeWayfarerInductionCharterUnitTests": (
        "eitherCharterCommitsOnlyStageElevenAndPreservesAllOriginalPropertyAndReceivingHistory",
        "fixedOperatorTermsRejectAlteredCapacityMinimumUnitsAndForeignEpoch",
        "choiceRequiresOwningLaterAvenorDockAndCannotReplaceAnExistingPolicy",
        "owningChoiceClaimsNeedAcknowledgementActualStationAndCurrentClockBounds",
        "boardOffersBothPoliciesAndShowsSelectedCapacityConsequencesBeforeConfirm",
        "closedChoiceSchemaKeepsEarlierUtilityAndRejectsEarlyEmbeddedAndUnknownCharterTerms",
    ),
    "NativeWayfarerInductionUtilityWorkUnitTests": (
        "maintenanceEnvelopeRequiresEveryFrontSurfaceSpeedAimAndOcclusionBoundary",
        "onlyPositiveBoundedNativeIntervalsCreditAndNeverExceedTwentySeconds",
        "partialWorkRoundTripsWithoutSpendingKitsRepairingControlsOrAdvancingStageTen",
        "rearmingPreservesEarlierPartialTimeAndRejectsOverlappingOrDuplicateArmHistory",
        "originalKitAndWorkingControlMustChangeTogetherWithCompleteBoundRepairHistory",
        "liveReceivingNeedsAllThreeDistinctOriginalRepairsAndOnlyThenUnlocksStageTenOnce",
        "workAndReceivingClaimsNeedOwningAcknowledgementsClockAndReverseSourceJoin",
        "maintenanceReviewBindsPaintedConfirmAndHeldReturnCannotLeakIntoWeaponsAfterStop",
        "closedWorkEnvelopeRejectsEarlierSchemaUnknownProgressAndUnpairedReceivingFields",
    ),
    "NativeWayfarerInductionUtilitySourceUnitTests": (
        "exactInitialEnclosuresKeepPhysicalMetresSeparateFaultsAndFiniteOriginalCrewKits",
        "sourceAuthorizationNeedsPriorActualReceptionAndOwningLaterEnronDockWithoutProgress",
        "originalSourceGraphRequiresBothAcknowledgementsOwnerActualStationAndSingleIssue",
        "nativePreparedConditionKeepsActualOriginalModelAndCannotBecomeEquipmentOrCargo",
        "actualAdmissionClaimsNeedThreeOriginalNativeActorsAndKeepFaultAndKitStateUnchanged",
        "exactInternalPackPinsThreeSourcesAndLuaCannotRepairConsumeKitsOrAdvanceStageTen",
        "closedUtilityEnvelopeRejectsEarlierForeignUnknownAndExtraModuleClaims",
    ),
    "NativeWayfarerInductionRescueReceivingUnitTests": (
        "originalSurvivorsAndRecorderReturnReleaseExactlyOneTonneAndOnlyStageNineOnce",
        "foreignEmptyDuplicateCrewWrongRecorderOrWrongActualCradleCannotReceive",
        "unusedRescueFundsReturnOnlyToOriginalCevilisCustodianOnceAndCloseFuturePurchases",
        "owningSourceMustShareReceivingAndClosedBankWithoutLeavingDuplicatePeopleAboard",
        "everyActualOwnedHopNeedsArrivalAndFinalReferenceBeforeReceivingCanBeQualified",
        "closedReceivingSchemaRejectsEarlierOrUnknownReceiptAndRetainsUnreceivedService",
    ),
    "NativeWayfarerInductionRescueServiceUnitTests": (
        "berthHistoryRequiresOriginalVesselObservedBindingAndExactlyOneUnexitedContact",
        "paidServiceConservesOnlyNeededTankFuelOwnCashAndSamePersistentSupplierStock",
        "servicePurchaseCannotClaimAnotherRouteHopOrFutureQuoteAndStockNeedsOwningBank",
        "unavailableSupplyPersistsFiniteRefusalWithoutTankCrewOrStockCreation",
        "berthExitNeedsSameWorldFreshNativeHullAndPaidContactBeforeItCanClearDock",
        "closedServiceEnvelopePreservesEarlierFlightAndRejectsEarlyOrUnknownBerthClaims",
    ),
    "NativeWayfarerInductionRescueFlightUnitTests": (
        "routeConsentBindsTheSameOriginalPeopleFundingAndCapturedRetainedFuelWithoutProgress",
        "hopReferencesAreOriginalJobBoundAndSequentialWithBoundedRetryRatherThanTeleport",
        "actualOwnedDepartureReferenceSpendsExactlyCapturedFuelAndCannotInventAnotherLeg",
        "movingOrRelocatedLaunchNeedsItsOwnActualTransitAndCannotUseAnArrivalMarker",
        "realLaunchLossAlongTheAuthoredRouteKeepsOriginalCrewLostAndRecorderHistoryHeld",
        "closedFlightEnvelopeRetainsEarlierFundingButRefusesEarlyForeignOrUnknownTravel",
    ),
    "NativeWayfarerInductionRescueFundingUnitTests": (
        "originalRescueFundingAndUncrewedReserveAreFiniteDistinctAndDoNotCreatePeople",
        "reachableOriginalCatalogueRouteKeepsBurroDriveTankAndActualMeasuredHops",
        "rescueAndArkPurchasesShareOneExistingStationAllocationWithoutSharingEscrows",
        "onlyNeededFuelUsesActualUnitsAndRefusesForeignStockAndDriveOrTankViolations",
        "finiteRescueBudgetCanRunOutAndColdDecodeCannotReplenishOrHideRefusal",
        "fundingClaimsNeedOwningAcknowledgementsAndRealLegacyRebriefHistoryWithoutSourceReset",
        "closedFundingSchemaRejectsEarlierInventedBalancesAndUnknownNestedReserveClaims",
    ),
    "NativeWayfarerInductionCrewLogPickupUnitTests": (
        "legitimatePortableHullExchangeKeepsPickupHistoryAndAllowsBothLaterLossCauses",
        "unrelatedHullOrOwnerCannotClaimRecorderCustodyAndOldSchemasRejectTransferClaims",
        "originalPickupReservesExactlyOneTonneAndOnlyStageEightWithoutBoardingOrReward",
        "duplicateForeignOrFullHoldPickupCannotReplaceTheOriginalUnitOrEarlierHistory",
        "safeScoopRequiresTheMeasuredPackageInsideEveryApertureAxisAtNativeRelativeSpeed",
        "receiptNeedsTheActualFittedScoopOriginalPhysicalMarkerAndPositiveNativeFrame",
        "laterActualCarrierLossReleasesOnlyTheRecorderTonneAndKeepsOriginalPickupAndCrew",
        "owningGraphRequiresBothPickupReceiptsAcknowledgementsAndOriginalRemovedUnit",
        "closedPickupEnvelopePreservesSourceOnlySavesAndRejectsEarlyOrUnknownPickupClaims",
        "optionalSalvageGuidanceKeepsTheSamePhysicalScoopAndDoesNotRequireCabins",
    ),
    "NativeWayfarerInductionCrewLogProducerUnitTests": (
        "sourceGraphNeedsTheSameParentOwnerAcknowledgedIssueAndRetainedMainStation",
        "registrationBindsOneOwningOriginalManifestActualCevilisVisitAndPriorReceiving",
        "livingCrewRequiresDistinctActualAdmissionAndLaunchLossCannotBecomeARescue",
        "mechanicalFailureDisablesOnlyTheOriginalTenderDriveWithoutSpentHullOrEmpCredit",
        "initialNativeResourcesUseSourceShieldsAndOnlyOneScriptFuelReservoir",
        "internalPackPinsAllThreePhysicalSourcesAndCannotGrantPickupOrReceivingFromLua",
        "closedSourceEnvelopeRejectsOldEmbeddedForeignAndUnknownNestedClaims",
    ),
    "NativeWayfarerInductionCrewLogSourceUnitTests": (
        "exactBurroMetreSourceKeepsOriginalPerformanceAndSeparateMechanicalFailure",
        "oneOriginalRecorderNamesExactlyTwoDistinctLaunchOccupantsAndEnmadanShelter",
        "preparationNeedsOriginalStageSevenHistoryAndCannotIssuePickupOrRescueProgress",
        "referenceTransformUsesPhysicalMetresAndRejectsForeignInvalidOrMirroredAnchors",
        "authenticatedPackageShellAndBothFitsRefuseChangedModelsOrProfiles",
    ),
    "NativeWayfarerInductionArkRecoveryUnitTests": (
        "oneInitialReserveHasDistinctFiniteHullSeedCrewAndFuelFundingIdentities",
        "replacingTheLostArkKeepsOriginalKeyAndHistoryWithoutPaymentOrMilestoneProgress",
        "originalKeyLossCannotBeHiddenByReserveConsentOrMintAReplacementKey",
        "retiringOldEscrowAndIssuingReserveFundingConservesBothSeparateFiniteAccounts",
        "recoveryJoinRequiresRetainedActualLossBothOwnedJobsAndTheSameAcknowledgedSourceTransaction",
        "closedRecoverySchemaRejectsOldForeignOrReplenishedReserveAndRetainsLegacyRebriefOrigin",
    ),
    "NativeWayfarerInductionArkReceivingUnitTests": (
        "originalKeyReturnReleasesExactlyOneTonneAndUnlocksOnlyStageSevenOnce",
        "foreignKeyWrongCradleAndAlteredOriginalManifestCannotCompleteReceiving",
        "unusedEscrowReturnsOnlyToItsCustodianOnceAndCannotFundFurtherFuel",
        "everyOriginalRouteLegMustHaveItsActualOwnedArrivalBeforeReceivingCanJoin",
        "sourceJoinRefusesSubstituteFortyUnitLoadsOrCrewAndAnyLostOriginalArk",
        "receivingSchemaRejectsEarlyParentReturnAndEscrowClosureClaims",
    ),
    "NativeWayfarerInductionArkServiceUnitTests": (
        "stationReserveIssuesOnceByWorldAndStationRatherThanArkVisitOrQuote",
        "paidTransferConservesSameCapturedSupplierReserveAndCustodianEscrowAndRejectsReplay",
        "supplierQuoteNeedsTheActualStationVisitAndBoundedCurrentPhysicalTime",
        "dockingContactAndBerthExitKeepOneOriginalManifestAndRequireTheirNativeIdentityLinks",
        "nativeCrossingNeedsForwardAlignedSlowAttainedEntryAndNeverAnApproachOrDeparture",
        "fuelReserveSchemaPreservesEarlierRegistrationButRejectsOldAndUnknownSupplierClaims",
    ),
    "NativeWayfarerInductionArkProducerUnitTests": (
        "launchConsumesOnlyOneOriginalRegistrationAndKeepsKeyMassAndEarlierReceipts",
        "routeFitsBothTheOriginalArkAndEscortWithoutChangingAuthoredDriveOrTank",
        "admissionAndPhysicalLossKeepOriginalManifestsWithoutManufacturingCrewOrReceiving",
        "hopReferencesBindExistingNativeLegIdentityAndRefuseForeignJobsAndUnboundedRetries",
        "internalPackPinsOriginalGeometryAndOnlyRequestsActualNativeAdmission",
        "arkEnvelopeRefusesOldMisplacedUnknownAndHalfPinnedServiceClaims",
    ),
    "NativeWayfarerInductionArkFuelUnitTests": (
        "actualCatalogueRouteUsesReachableHopsAndAdvertisesItsRealRefuellingDependency",
        "quoteBuysOnlyNeededNativeTenthsWithinTheRealDriveAndTankAndConservesEscrowAndStock",
        "wrongNativeDockChangedSupplierQuoteAndRepeatedContactCannotDebitOrRefill",
        "finiteOpeningIssueCanRunOutAndRecordsARefusalWithoutMintingCashFuelOrNewStock",
        "closedEscrowRoundTripRetainsPurchasesAndRefusalsAndRejectsInventedFundsOrNestedClaims",
    ),
    "NativeWayfarerInductionArkSourceUnitTests": (
        "sourceUsesOnlyTheAuthenticatedCalibratedHaflingerAndExistingFlightUnitConversions",
        "oneKeyBoundManifestKeepsOriginalUnitAndCrewIdentitiesWithoutGrantingAdmissionOrArrival",
        "mismatchedConsentServiceAndProfileModelsCannotBindAnArkSource",
    ),
    "HaflingerPhysicalContractUnitTests": (
        "explicitTwentyMetreCalibrationPreservesEveryOriginalCoordinateAndPhysicalFeature",
        "calibrationRejectsForeignOrChangedSourceAndNeverConvertsAnUnapprovedHull",
        "physicalSourcePresentationLabelsCalibrationAndKeepsPerformanceAndActivationSeparate",
    ),
    "NativeWayfarerInductionVaultKeyUnitTests": (
        "keyLoanNeedsCompletedOriginalServiceActualEnlirinConsentAndFreeHold",
        "oneOriginalLoanPreservesCustodianOwnershipAndReceivingRestrictionWithoutEscortCredit",
        "keyLossReleasesMassButRetainsTheOutstandingOriginalLoanAndAllEarlierReceiving",
        "keySchemasReadEveryEarlierStageButRefuseEarlyUnknownOrReleasedLoanClaims",
    ),
    "NativeWayfarerInductionCassetteServiceUnitTests": (
        "sharedNativeRepairTransitionRequiresTheSameFailedSerialAndRejectsASecondService",
        "serviceNeedsTheOriginalUnitActualRenasNativeConditionAndItsOwnersReceipt",
        "servicedOriginalReturnsOnceReleasesItsTonneAndKeepsClinicAndWorkshopHistory",
        "serviceSchemasKeepEarlierEvidenceButRejectServiceInOlderOrAlteredEnvelopes",
    ),
    "NativeWayfarerInductionContinuationUnitTests": (
        "clinicReceptionNeedsTheExactOriginalCoolingUnitActualNavidorAndPositiveQuality",
        "receptionConsumesOneReservationWithoutDeletingCargoOrResettingThePickupClock",
        "workshopCassetteNeedsPriorReceptionActualEnmadanAndFreeHoldAndCannotReissue",
        "cassetteCarrierLossKeepsClinicHistoryAndNeverCreatesReplacementsOrAReward",
        "continuationSchemasPreserveLegacyOpeningButRefuseNewOrUnknownClaimsInOldEnvelopes",
        "boardRoutingFollowsOriginalStageLocationsAndKeepsAccreditationLocked",
    ),
    "WayfarerFieldReliefRetirementUnitTests": (
        "laterRealLossRetiresHeldOriginalsWithoutChangingTheFailedMission",
        "lostCargoRequiresActualCauseEnergyAndBoundedNativeTimeAndVisit",
        "custodyJoinRejectsReplacementBatchesAndPreviouslyInstalledMaterials",
        "laterUnpaidReturnAndLossRoundTripKeepTheOriginalReceiptAndClosedSchema",
    ),
    "NativeWayfarerInductionUnitTests": (
        "inductionRequiresAnOwnedRecordedSaleOrActualCompletedDeliveryAndNeverAGenericFlag",
        "clinicPickupNeedsFreeHoldAndTheExactLaterRenasSourceAndCannotReissueTheOriginal",
        "fixedArmedFlightDeadlineSurvivesPauseAndLoadingWithoutBorrowingTheServiceAllowance",
        "actualCarrierLossReleasesTheReservationWhileRetainingConsumedStockAndRejectingReplay",
        "strictInductionSchemaRejectsOldUnknownAndRewrittenDeadlinesAndPreservesLowerFeatures",
        "bundledInductionSupportsOnlyCommissionAndClinicPickupWithItsOwnPublishedAllowance",
    ),
    "NativeFirstCommoditySaleUnitTests": (
        "nativeSingleAndBatchSalesRequireAllThreeActualBalancesAndTheOriginalQuote",
        "saturatedCashAndHugeFiniteBatchRevenuePreserveTheActualCreditCapWithoutOverflow",
        "immutableSaleRoundTripRetainsEvidenceWithoutGrantingCampaignOrClueProgress",
        "strictSaleSchemaRejectsOldMisplacedUnknownAndMissingEvidenceAndLowersAllEarlierFeatures",
    ),
    "OriginalHullPhysicalContractUnitTests": (
        "burroUsesExactAuthoredNativeMetresAndKeepsOriginalSpecificationsSeparate",
        "missingUnitsForeignIdentityAndChangedSourceCannotBecomePhysicalAuthority",
        "offCentreOriginRequiresLargerClearanceThanNormalisedOrCentredHalfExtents",
    ),
    "ShowroomComparisonUnitTests": (
        "compactAndWideSpecsShowBothCurrentAndPinnedModelsWithoutChangingBrowseMode",
        "bothRenderedPreviewsKeepTheSamePitchRollAndYawThroughRotationAndPause",
        "comparisonMatchesQuotedPriceAndActualTransferredFitWithHonestRatings",
    ),
    "ShipComparisonPrecisionUnitTests": (
        "equalDisplayedTenthsIncludingHalfwayValuesAlwaysReceiveSameRating",
        "visibleDifferencesKeepTheCorrectBenefitDirectionWithoutSubtractionOverflow",
        "unknownNonFiniteAndIncompatibleValuesNeverGetInventedEqualityOrBenefits",
    ),
    "FleetCataloguePreviewUnitTests": (
        "onlyTheOwnersRecordedEncounterRevealsWireframeAndOwnershipRetainsShading",
        "rotatingSilhouetteKeepsProjectedHullButRevealsNoMaterialsTexturesOrInternalEdges",
        "silhouetteClipsNearPlaneAndViewportAndRefusesNonFiniteProjectionInputs",
    ),
    "NativeGlassMeridianUnitTests": (
        "unacceptedOpeningRoutesToTheActualBoardAndRejectsChangedPackPins",
        "entryRequiresThreeDistinctActualWorldsAndTwoIdentifiedTypesFromTheSameOwner",
        "contiguousNativeDwellSealsTwelveSecondsAndChangingTargetOrClockRestartsIt",
        "eitherClockOrderIsValidButDuplicateForeignAndOverlappingReadingsCannotAdvance",
        "destroyedUnreadClockRequiresNewLogicalAndPhysicalIdentityWhileKeepingCompletedEvidence",
        "strictOpeningSchemaLowersThroughFleetAndRejectsOldOrUnknownClaims",
        "openingPackPinsRealClockGeometryAndAllNineAuthoredMilestonesWithoutATerminal",
    ),
    "NativeFleetDiscoveryUnitTests": (
        "encounterAndIdentificationNeverGrantBlueprintWithoutPlayerDestruction",
        "npcKillsForeignOwnersUnknownTypesAndBackdatedEvidenceRefuseAtomically",
        "stationCollectionNeedsActualDockingEvidenceAndCannotCreateABlueprint",
        "nonstationCapitalDestructionCompletesItsOwnMilestoneWithoutPurchaseRights",
        "strictDiscoverySchemaPreservesLowerFeaturesAndRejectsNestedUnknownFields",
    ),
    "EquipmentModuleReadoutUnitTests": (
        "authoredShieldEnergyAndNavigationOfferValuesUseTheirOwnBasicBaseline",
        "actualFittedUpgradesAndAsymmetricShieldsRemainVisibleWithoutChangingTheComponent",
        "absentForeignAndUnsupportedComponentsNeverBorrowAnotherFamiliesPercentages",
        "percentageFormattingRefusesUnknownNonFiniteOrZeroBaselinesWithoutInventedImprovements",
    ),
    "SolarFuelCollectionUnitTests": (
        "onlyActualFuelScoopsFittedToTheActiveHullSupplyCollection",
        "fractionalCollectionSurvivesFrameBoundariesAndStopsAtActualCapacity",
        "collectionRefusesMissingScoopsReverseLateralOutOfRangeAndSurfacePositions",
        "nonFiniteInputsAndHugeGainsCannotTrapOrOverflowTheTank",
    ),
    "NativeFlightReceptionUnitTests": (
        "positiveBoundedAlignedApproachRetainsExactAuthorityAndRoundTrips",
        "changedAuthorityClockOrUnmovedPoseCannotSupplyApproachEvidence",
        "wrongAimRangeAndNonClosingMotionRefuseQualification",
        "receptionRequiresMeasuredSameBerthLaterDoorwayReceiptAndSeparatePermission",
        "strictLeafAndSharedSchemaPreserveLowerNativeFeatureGates",
        "bundledLessonPinsCurrentFitZeroPaymentAndClosedNativeDeclaration",
    ),
    "OriginalFleetCatalogueUnitTests": (
        "exactCatalogueJoinsPreserveAllOriginalIdentitiesRolesAndAccessRules",
        "sourceProfilesRetainEveryAuthoredFieldAndDoNotReplaceExistingProfiles",
        "sourceDisplayKeepsLargeIntegersAndNestedValuesWithoutFloatingConversion",
        "sourceRangeConflictsAndQuestRestrictionsRemainExplicitAfterJoining",
    ),
    "PortableHullTransferUnitTests": (
        "smallerHullStoresPortableOverflowWithItsActualItemAndComponentHistory",
        "installedFamilyLimitStoresExcessEvenWhenSlotsRemainSupported",
        "returningToALargerHullDoesNotRefitStoredSparesOrRecreateSoldBoundItems",
        "foreignOwnerUnknownNodeAndExhaustedRevisionRefuseWithoutChangingSource",
    ),
    "ContextControlHintUnitTests": (
        "systemScrollHintsFollowActualViewportAndHelpReturnContext",
        "inventoryPagingHintsDisappearWhenAllRowsFitAndRetainSharedFlightControls",
    ),
    "FlightControlAuthorityUnitTests": (
        "allSharedFlightBindingsRoundTripWithoutFunctionKeys",
        "targetSelectionAndFilterInterruptTheHeldToolWithoutBecomingFire",
        "generatedHelpRowsRemainBoundedAndKeepMenusScoped",
    ),
    "TrackpadContactSafetyTests": (
        "rejectedSystemGestureStaysSuppressedWhenContactsDropToSteering",
        "modeChangeCannotRearmAnInvalidTouchUntilEveryFingerLifts",
        "callerModeTransitionPreservesRejectionBeforeTheNextTouchEvent",
        "callerModeTransitionClearsActiveControlsSynchronously",
        "explicitLifecycleResetStillClearsRejectionAndActiveContacts",
    ),
    "AsteroidDebrisContactTests": (
        "aMaterialCornerResponseSeparatesAllCertifiedFacesWithoutAddingEnergy",
        "aThreeFaceResponseRetainsAuthoredRestitutionAndMomentum",
        "aContinuedContactInsideTheFirstLeafAdvancesItsCertifiedFrontier",
        "impulseConservesBothMassesAndLinearMomentumWithExplicitDissipation",
        "crossedThinBarsHaveAnEdgeContactEvenWhenNoVertexEntersAFace",
    ),
    "NativeMeasuredExtractionDomainTests": (
        "extractionOriginalsAreFiniteStableAndOwnerScoped",
        "fieldReliefLowersThroughMeasuredExtractionBeforeRecordRecovery",
        "sharedClosedEnvelopeAcceptsBothBoardsAndRejectsClaimsUnderOlderVersions",
        "closedEnvelopeRejectsMissingMeasuredLeafAndMixedNativeDeclarations",
    ),
    "BundledScriptPackTests": (
        "bundledMeasuredExtractionDeclaresActualTwentyTonneSourceAndClosedTwelveTonneRecipe",
    ),
    "MarketInventoryProjectionUnitTests": (
        "statusSummaryAndInventoryHaveDistinctResponsibilities",
    ),
    "InventoryGroupingUnitTests": (
        "mixedTradeAndReservedCargoStayInDistinctSectionsWithoutChangingQuantities",
        "fittedAndHeldSectionsKeepEveryExactItemSubjectAndActionPreviewOnce",
        "emptyOwnedStorageAndLegacyFittingsRemainExplicitWithoutInventedCustody",
    ),
    "PlanetNightTechnologyUnitTests": (
        "originalWorldNightProfilesRetainEveryAuthoredTechnologyLevel",
        "matchedOriginalEconomyAndGovernmentKeepIncreasingNightDevelopmentAboveFifteen",
        "explicitLegacyNightProfilesKeepTheirExistingCoefficientsAndBounds",
    ),
    "NativeUtilityCustodyTests": (
        "explicitWorldActivationOwnsEightMaterialsWithoutTargetDockAuthority",
        "strictCurrentUtilitySchemaRejectsUnjoinedOrInventedClaims",
        "targetRequiresUtilityStateAndOtherStationsCannotClaimIt",
    ),
}


def selection() -> str:
    """Use exact suite/method boundaries; never expand to whole mixed suites."""
    return "|".join(
        rf"(?:^|\.){re.escape(suite)}/{re.escape(method)}\("
        for suite, methods in METHODS.items()
        for method in methods
    )


def inspect_report(path: Path) -> dict:
    """Require every selected method, actual cases and no failures/errors."""
    root = ET.parse(path).getroot()
    cases = list(root.iter("testcase"))
    if not cases:
        raise ValueError("The isolated-unit report contains no test cases.")
    if list(root.iter("failure")) or list(root.iter("error")):
        raise ValueError("The isolated-unit report contains failures or errors.")
    selected = {(suite, method) for suite, methods in METHODS.items() for method in methods}
    observed = {
        (case.attrib.get("classname", "").rsplit(".", 1)[-1],
         case.attrib.get("name", "").split("(", 1)[0])
        for case in cases
    }
    if observed - selected:
        raise ValueError("The report includes methods outside the isolated selection.")
    if selected - observed:
        raise ValueError("Missing selected unit methods: " + ", ".join(
            method for _, method in sorted(selected - observed)))
    for suite in root.iter("testsuite"):
        if any(int(suite.attrib.get(key, "0")) for key in ("errors", "failures", "skipped")):
            raise ValueError("A test suite reports errors, failures or skipped units.")
    if list(root.iter("skipped")):
        raise ValueError("A selected isolated unit was skipped.")
    return {"methods": sum(map(len, METHODS.values())), "reported_testcases": len(cases)}


def main() -> int:
    """Record exact source, command, output and nonempty xUnit results."""
    report = ROOT / "reports" / "isolated-units"
    report.mkdir(parents=True, exist_ok=True)
    xml = report / "tests.xml"
    swift_xml = report / "tests-swift-testing.xml"
    xml.unlink(missing_ok=True)
    swift_xml.unlink(missing_ok=True)
    result_path = report / "result.json"
    result_path.unlink(missing_ok=True)
    sha = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    command = [
        os.environ.get("SWIFT_EXECUTABLE", "swift"), "test", "--jobs", "3",
        "--enable-code-coverage", "--xunit-output", str(xml), "--filter", selection(),
    ]
    result = {"commit": sha, "command": command, "status": "failed"}
    evidence = IsolatedCrashEvidence(ROOT, report / "failure-evidence")
    try:
        with (report / "output.log").open("w", encoding="utf-8") as log:
            with subprocess.Popen(
                command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                text=True, encoding="utf-8", errors="replace",
                env=runtime_child_environment(os.environ),
            ) as process:
                evidence.start(process)
                assert process.stdout is not None
                for line in process.stdout:
                    print(line, end="", flush=True)
                    log.write(line)
                code = process.wait()
        result["exit_code"] = code
        if code:
            return code
        # SwiftPM emits the Swift Testing report with this suffix, separately
        # from any XCTest report produced for the requested base filename.
        actual_xml = swift_xml if swift_xml.is_file() else xml
        result.update(inspect_report(actual_xml))
        result["report"] = actual_xml.name
        result["status"] = "passed"
        return 0
    except (OSError, ET.ParseError, ValueError) as error:
        result["error"] = str(error)
        print(str(error), file=sys.stderr)
        return 1
    finally:
        try:
            result["failure_evidence"] = evidence.finish(sha, failed=result["status"] != "passed")
        except (OSError, ValueError, subprocess.SubprocessError) as error:
            result["failure_evidence"] = {"captureError": type(error).__name__ + ": " + str(error)}
        result_path.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    sys.exit(main())
