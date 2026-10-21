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

ROOT = Path(__file__).resolve().parents[2]
METHODS = {
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
    try:
        with (report / "output.log").open("w", encoding="utf-8") as log:
            with subprocess.Popen(
                command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                text=True, encoding="utf-8", errors="replace",
            ) as process:
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
        result_path.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    sys.exit(main())
