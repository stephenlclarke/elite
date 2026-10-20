# test(fixtures): declare cash and compatible hull exchange prerequisites

## Change and preserved behavior

The two selected scripted mission methods and the deadline method explicitly initialize 1000 tenths before mission acceptance. Their 1000/1500 reward, full rollback, expired failure-payment, refund, cargo and once-only assertions are unchanged. The rollback method's full-hold control uses the same explicit cash as its malformed-command cases.

Only the two selected owned-event methods use a new file-private stock Cobra fixture. It constructs SH023, its authored full 70 fuel and four physical missiles before current typed equipment initialization, then mirrors fitting, migrates current mining presence and initializes native player energy/shields. No runtime equipment grant or gameplay refill is added. The existing SH023-to-SH013 event, physical round IDs, inventory fit/store/fire events, writer refusal/commit, persisted reload and no-replay assertions remain exact. The common missionGearGame helper and every other caller remain unchanged.

The stale-contract hull exchange initializes fuel from the genuine SH013 performance before creating the original frozen quote. The positive unpriced-admission control initializes fuel from its actual independently loaded positive hull before equipment preparation and commander capture. Both require a valid starting commander. Original cash, resource transfer, stale-resource and never-purchase refusal oracles are unchanged. Source TOMLs independently establish SH025 fuel 130, SH023/SH013 fuel 70, four SH023/SH013 pylons and compatible laser facings; no target value is inferred from a failed runtime result.

## Exact focused selection

Request one matching build and these seven methods / eight expanded cases under G1's compiler lease:

- scriptedCourierUsesAtomicCustodyConfirmAndNeverReplaysReward: one case.
- scriptTransactionsRollbackAllEffectsOnFitErrorUnknownCommandsAndScriptFaults: one case; its original three malformed-command controls remain internal.
- genuineDeadlinePulsesAndLateHandoffsUseFrozenFailureTermsWithoutRevivingSuccess: one case; original false/true failure-payment controls remain internal.
- hullChangeEventAndOwnedFitShareTheirActualActorWriterCommitOrRollback: false/true, two cases.
- scriptsObserveOnlyCommittedHullRefitAndActualAmmunitionEvents: one case.
- hullChangesInvalidateOldQuotesAndRevealTheSameOfferWithItsNewActualFit: one case.
- actualTradeQuoteRefusesUnpricedNeverWithoutChangingPositiveQuoteOrCommander: one case.

Strict scoped Swift formatting, Markdown lint, diff checks and source conservation are author prerequisites. All removed source lines are the two selected calls to the generic starter fixture; every original assertion remains byte-exact. Exactly four test paths plus this paired handoff are owned. One independent bugs/performance/style review is requested. Author execution is none; focused qualification remains pending and no CI, crash resolution, G05 result or release completion is claimed.

## Compatibility and remaining risks

No production, native defaults, TOML, resources, saved format, shared helpers or G05-owned paths change. Other triage groups and the audio save-projection ambiguity remain separate. Existing full hosted failures are retained and no partial run is converted to PASS. The setup is source-proven, while complete selected behavior still needs actual execution. Companion: [ISSUE-hosted-cash-hull-fixtures.md](ISSUE-hosted-cash-hull-fixtures.md).
