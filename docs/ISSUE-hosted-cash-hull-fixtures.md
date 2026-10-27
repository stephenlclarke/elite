# Hosted runtime fixtures inherit unrelated fresh-start cash and fuel

## Actual evidence and scope

Hosted head 43a720427baa3a1dd17950539c2d785c04658bc4 compiled production and tests with Swift 6.1.2, then recorded 30 runtime issues before unattributed SIGBUS termination. The approved first batch covers only seven named methods / 17 recorded issues in ScriptMissionTests, ScriptContractTests, OwnedEquipmentTests and UnpricedShipAdmissionTests. The complete triage is /tmp/elite-g2-hosted43-runtime-triage/GROUPED-CAUSAL-TRIAGE.json, SHA256 ffcff4e8c4cb66589e82cfd45b2a41ba024017273b6fe362174ecfa5ee94d530. All selected tests remain unchanged at canonical base 44db923834619831df2b2f205536a46d07151247, including the separately integrated G05 work.

The cash methods assert their original 1000/1500 accounting but inherit the approved 7200-tenths fresh balance. The actual 7700 courier result is consistent with that baseline plus the unchanged 500 reward. Positive hull exchanges inherit SH025's full 130 fuel while selecting SH013, whose native tank is 70; shipTransferIssues and native commander validity correctly refuse that transfer. The owned-event tests additionally assert an SH023 predecessor while their generic helper inherits SH025.

## Required correction

Declare the intended initial cash or compatible fit only in the selected fixtures. Retain all original expected money, four owned missiles, SH023-to-SH013 events, refusal/rollback, stale quotes, frozen offers, positive price and unpriced-never assertions. Do not change fresh defaults, shared fixture defaults, production fit rules or any other triage group. The hosted SIGBUS has no matching crash artifact and is not attributed to these failures or the independently diagnosed MBA G05 crash.

## Assignment registration

M01-hosted43-cash-hull-fixtures is assigned to G2 for scoped authoring and one independent review; G1 owns matching compiler/runtime execution and normal central ledger integration. Source is authored, qualification pending, release acceptance open. The external frozen assignment record and paired PR notes retain the exact seven-method / eight-expanded-case selection. Companion: [PR-hosted-cash-hull-fixtures.md](PR-hosted-cash-hull-fixtures.md).
