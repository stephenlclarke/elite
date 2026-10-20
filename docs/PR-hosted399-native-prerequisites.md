# test: establish explicit native prerequisites for hosted courier and property cases

## Change

Seven selected courier methods now use existing CourierNativeFixture.game(using:) before board/equipment initialization. Known feasible listings are verified against the unchanged seed, draws, UUID, path and calendar-cost witnesses. The prior-unavailable method uses its own pinned fit, preserving all three frozen refused routes. The full-hold test uses origin0 data row2 for its initial data-only quote and fixed row2/row1 for data/package acceptance; the same variant and deadline precondition remains mandatory. No row search, witness update, refresh or reroll is added. Existing acceptance/travel helpers remain unchanged.

The selected loan method establishes stock SH023 fuel/energy/shields before the same real acceptScriptMission flow. Fuel70 before and after the loan, tank capacity140, rear beam mount and actual store/return checks remain exact. The clue hull-exchange method sets transferable fuel from the actual selected SH013 performance before its unchanged paid quote/confirmation, preserving owner and permanent journal. The hourly refresh method sets1000 initial cash before runtime/board creation.

All original #expect lines are retained. Existing custody, physical hold, native travel, writer refusal/retry, stale confirmation, controls rollback, receipt exactly-once, missing-content, version corruption, byte/hash/schema, clue identity/progress, loan modules/fuel and accepted-contract freezing oracles remain intact. Shared fixture factories, CourierNativeFixture and every witness, production/resources/defaults, all other methods and previously qualified cohorts are unchanged.

## Exact selection and case accounting

- courierOneTonneUsesRealHoldAndDataNeedsNoSpareTonne: one case, internal data/package loop.
- courierPriorInputsKeepTheirDrawsAndRefuseInfeasibleCurrentWorldRoutes(pinned:): three priorUnavailableRows cases.
- courierOriginalEventCannotBorrowLaterConfirmationOrOutliveDrainBudget: one case.
- courierFailedAcceptanceAndHandoffPublicationRetainOriginalGeneration: one case.
- courierVersionClaimsAndCorruptPhysicalProjectionAreRejectedWithoutPublication: one case.
- courierMissingContentNativeFailurePublishesSharedReceiptAndConsumerOnce: one case.
- courierEscapeUsesActualNativeActionAndCommandPublicationRollsBackControls(variant:): two cases, data/package.
- declaredLaserAndTankLoansUseActualMountsStorageAndFuelWithoutARefill: one case, internal laser/tank loop plus invalid-declaration checks.
- actualHullExchangePreservesPermanentClueOwnershipAndProgress: one case.
- hourlyRefreshRefusesAStaleOfferAndNeverRerollsTheAcceptedContract: one case.

Total ten methods/thirteen declared cases addressing twenty-one recorded hosted issues, not thirteen new tests or a full-suite PASS. No shared helper is edited, so its other consumers retain exact dependencies and do not require repetition for this delta.

## Validation and limits

Scoped strict Swift format, Markdown lint, whitespace and original-oracle/source conservation checks precede freeze. One complete independent review and the exact frozen selection/dependency hashes are recorded in the handoff packet. G1 alone performs the matching warm build and selected runtime after its existing lease, with failures retained for diagnosis. No author compiler/build/test/native probe execution. Runtime qualification, hosted acceptance, global quality/review gates and release remain pending. The separate SIGBUS has no attributed site or fix claim. See [motivation](ISSUE-hosted399-native-prerequisites.md).
