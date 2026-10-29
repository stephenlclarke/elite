# fix(game): simplify contract board optional fallbacks

ContractBoardRow.key and the contract display's local detailReason now use explicitly typed sequential if-let returns. Each evaluates a later optional only when every earlier optional is nil. A present empty string is returned immediately, exactly as with the original nil-coalescing chains. No eager arrays/maps, common precedence helper or framework is introduced.

Row-key priority remains record recovery, identified salvage, survey, repair loop, cold chain, provider, people, finance, RRS, then the unchanged board/offer UUID-or-unavailable fallback. Display-reason priority remains record recovery, identified salvage, survey, repair loop, cold chain, provider, RRS, finance, people, generic quote, then selected row reason. The distinct orderings are intentional and retained.

Only the two expression hunks and these paired notes change from df62ccd4. No test, production policy, shared Game/Asteroid path, runtime setting or other compiler expression changes. This addresses the two actual Swift6.1.2 diagnostics; hosted repair is unproven until normal required CI.

## Qualification

Existing bounded native selection is four methods/seven cases, with no new mirror tests:

- WayfarerRecordRecoveryJourneyTests.completeNativeJourneyIdentifiesThenRecoversOneOriginalAndPaysSameCustodianOnce: one actual recorder journey.
- WayfarerRecordRecoveryJourneyTests.acceptanceBackAndActualMissingRequirementNeverAllocateSource: four hold/core/module/scoops refusals through the real board review and Back path.
- NativeIdentifiedSalvageJourneyTests.actualTwoOriginalJourneyReservesOnceAndPaysOnlyAtSameOwner: one actual identified-salvage journey.
- OriginalMutualContributionTests.actualReliefBoardShowsOneNamedFiveHundredRowAndBackDeclineTransferNothing: one actual native generic-board/detail/render/Back/Decline case.

Source parse/format/strict lint, independent ordering/fallback-preservation checks, paired Markdown and diff checks pass. These source checks are not native tests. G1 owns matching compilation and focused execution after the current MC1 native priority; causal compiler/unit corrections come first, followed by one independent bugs/performance/style review of the passing four-path freeze. No author native build, test, probe or full review runs. No current hosted compile fix, runtime crash repair, global pass or release completion is claimed. See [the actual compile failure](ISSUE-contract-board-compiler.md).
