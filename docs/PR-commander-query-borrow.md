# Preserve commander query values through a borrowed read

Synchronous orbital-outlook boarding can reach the commander query with repeated full Commander stack temporaries under debug instrumentation. Delegate the query to a private non-inlined helper through the existing read-only commander accessor. Its borrowing parameter shadows the Game property while the original query body stays byte-exact.

The change preserves every field and conditional section, evaluation order, native state/status query, ownership and authority check. There is no mutation, cache, persistence or pointer escape, and the GameRuntime and actor boundaries remain unchanged.

## Validation

MBA source formatting and strict lint pass; an inverse transformation restores the entire original source. ASCII, copied source hashes, Markdown lint, scope and diff checks are required at freeze. No author native job runs.

G1 owns matching native compilation and these existing six methods, six cases:

- authoredNativeRankEligibilityTracksAnActualLaserKillAndCannotEditTheRealCommander
- nativeStockAndMountedWeaponsQueriesFollowRealConsumptionWithoutMutatingInventory
- nativeCommanderQueriesDescribeActualCharterOccupancyAndLabelCrewEstimates
- nativeCommanderQueriesFollowAnActualHullExchangeAndPreserveCommodityUnits
- baseScriptSnapshotRetainsAllReadSectionsAndIndependentNativeValues
- NativeOrbitalOutlookJourneyTests/outlookFatalPhysicalLossClosesBothPeopleWithoutViewsPaymentOrClue

A full three-path independent review follows actual owner PASS. The original retained fault is verified against matching image/dSYM UUID and original hashes; focused results do not establish a successful public CI run.
