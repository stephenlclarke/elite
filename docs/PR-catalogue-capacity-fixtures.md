# Reconcile capacity tests without changing mission quantities

Updates only the ten assigned test files and this handoff pair. Capacity fixtures now read loaded native/physical hold values instead of assuming old balances. Full/refused holds remain genuinely full, guard/property/rollback assertions remain, and no runtime, catalogue, mission pack or historical source record changes.

| Fixture file | Adjustment and retained purpose |
| --- | --- |
| CommiesShipCatalogueTests | Pin current Ray30t/project usable25t while retaining historical remaining5t, crew and emitter facts. Test the Transporter's actual150t/151t boundary, current project status and preserved O08 native12t plus historical estimated0t. |
| EliteTests | Derive default/expanded hold, overflow by one, full market inventory and unlimited-cargo crossing from loaded performance. Preserve rank, cash, stock, kg handling, equipment charge and transaction/save assertions. |
| ShowroomTests | Compare project Cargo to loaded Cobra mechanics; compute selected Adder versus current Cobra cargo difference from those independently loaded values. Preserve unit compatibility, baseline and interface assertions. |
| ScriptPledgeTests | Use physical hold+1 as legacy excess and subtract the unchanged authored five-tonne donation. Preserve failed-fit-before/success-after, full receipt contents, cash, standing, outcome, idempotence and rollback assertions. |
| NavigationCustodyTests | Derive available room after a real5t cabin, fill the physical hold with the corresponding number of purchased cabins, and subtract unchanged one-tonne marked firearm/protected payload/technology reservations. Fill ordinary holds for tonne/non-tonne trading and retain graph/state nonmutation assertions. |
| RenderingReviewRegressionTests | Derive paid Cargo Bay hold and selected Boa base hold. Preserve the real bound-item removal, portable IDs, profile equality, quote and ownership/history assertions. |
| MissionPackTests | Fill actual ordinary hold before the protected courier-payload refusal. Keep its mission quantity, location rechecks and property guards unchanged. |
| NavalMissionTests | Fill the actual hold with ordinary Food while digital plans are collected/delivered. This changes personal full-hold setup, not a mission payload quantity; preserve stage/location, kills, reward, replacement hardware and unchanged cargo assertions. |
| BlackjackTests | Fill actual hold for firearm refusal, free exactly one tonne for the unchanged marked firearm, and test numeric capacity against that same hold. Keep the fixed20kg gold reward and overflow deferral arithmetic unchanged. |
| ScriptContractTests | Fill actual hold for declined-fit preservation and the stale-Cobra/fresh-Boa quote transition. Preserve the actual generated contract tonnage, other offers, deposit/cash, stale quote, save and rollback assertions. |

The former `fourPurchasedCabinsLeaveNoTonneTradeOrPurchaseRoom` is renamed `purchasedCabinsFillActualHoldAndLeaveNoTonneTradeOrPurchaseRoom`: the current30t Cobra needs six actual5t cabins, not four. Divisibility/count/full-hold checks remain explicit. Unlimited-cargo cabin cases derive the physical hold before applying the cheat so the fixture cannot accidentally use an unlimited numeric limit.

## Authored validation and handoff

Twenty-seven existing test methods are adjusted; the only declaration change is the cabin-test rename. Source review confirms no assertion-count decrease in any assigned file and preserves all fixed donation/firearm/protected-payload/gold quantities. Historical Ray remaining5t, transporter O08 max_cargo12t and estimated historical player0t remain explicit. All other files are unchanged.

Local checks are strict Swift formatting, scoped Markdown lint, whitespace, changed-file ownership, declaration/assertion-count and source-diff review. No compiler, typecheck, tests, native/GUI, media or build jobs ran here. G1 must execute the affected tests after source review; passing runtime behavior is not claimed by this handoff. Later unrelated runtime/discovery-policy failures remain with their owner rather than being bypassed by these capacity fixtures.
