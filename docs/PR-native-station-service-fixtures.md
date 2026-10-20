# test(stations): retain native quotes in service fixtures

## Problem and implementation

The station-service approach fixture fabricated a Food ask, invalidating OriginalLiveMarkets before its existing Commander validity guard. Retain authentic G04-S149 ask/bid 215/197 and change only quantity to ten. The original-main trading fixture also fabricated an ask and expected a zero-spread round trip. Pin G01-S007 ask/bid 226/208 and the separately rounded PLUGH quotes 170/156. Buy at the actual ask, sell at the actual bid, and assert stock ten to nine to ten with exact cargo and cash accounting. Explicit market/Commander validity prerequisites protect both setups.

Source inspection establishes that fuel ten is admitted by the current SH025 capacity 130; no hull or resource change is justified. The shared NativeStationTestFixture and every production path remain untouched. No station identity, actor, doorway, receipt, equipment ownership, authority epoch, paid fitting, refusal, persistence, rollback or nonmutation oracle is removed or relaxed. Existing shop fuel/storage/cabin operations remain unchanged.

## Validation and handoff

Author validation is limited to strict Swift formatting, scoped Markdown lint, whitespace checks, authenticated quote-byte verification and source conservation. No build, test, native probe or diagnostic campaign ran. G1 owns matching warm compilation and six selected methods/21 expanded cases, followed by one independent coherent review. Changing the helper invalidates any prior pass for its five methods/19 cases; neither Boolean paid-service case retains a prior pass.

The selected methods are actualEntryProvidesOnlySourceBoundBoardFacts (two station kinds), capturedBoardContextCannotSurviveChangedAuthority (11 authority changes), validatedLoadKeepsReceiptAndPropertyButReplacesBoardEpoch (two kinds), boardOnlyStationsRefusePaidShopsTradingAndRefuellingWithoutPropertyLoss (two kinds), boardOnlyDockStillAllowsValidOwnedEquipmentStorageAndRefitting (two kinds), and originalMainAndDiscoveredPlughKeepPaidFuelCabinsEquipmentAndMarkets (false/true). The file contains nine methods/28 expanded cases total; three methods/seven cases have unchanged setup and are outside this bounded qualification.

Exactly three paths change: one test and paired notes. No remote PR exists. Full CI, sanitizer, leak, coverage and release gates remain separate and open. Companion: [ISSUE-native-station-service-fixtures.md](ISSUE-native-station-service-fixtures.md).

## Prior fixture correction record

### Change and preservation

The launch/manual-cancel cases send key 0 through the same GameRuntime input path before their original optional Q and undocked/context invalidation checks. The exact main-arrival method creates its empty temporary save directory during setup, retaining the strict enumerator and file-invariance comparisons.

Actual physical docking, current typed receipt/destination, owner, epoch, replacement, lifecycle and negative authority assertions remain. No production geometry, receipt, launch, paid-service or save guard changes. The directory setup supplies a filesystem prerequisite and does not manufacture arrival authority.

See [the observed cause](ISSUE-native-station-service-fixtures.md).

### Validation and risks

Strict Swift/Markdown lint and diff checks pass; inverse setup transformation reconstructs each affected original test file exactly at `861ab718c06adb841847dca395f1ee5b4e9edf03`. This worker has not compiled or executed the batch. Runtime behavior and full CI acceptance remain unestablished until the integration owner completes validation.

### Shared typed exit proof

The one approved `NativeStationIntegrationTests.verifyNativeEntryAndExit` call now also sends actual launch key 0. All original per-kind entry, disk receipt, sequence, calendar, exit geometry and pose assertions remain. Reversing this single input replacement reconstructs the entire original integration test file. No extra execution or broad input replacement occurred in this worker.
