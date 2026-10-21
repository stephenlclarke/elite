# Equipment modules and accumulated upgrades

Current development equipment uses three navigation/energy grades and seven shield grades. The shop translates preserved save keys into module names and shows the actual fitted grade. New commanders receive Basic shield, navigation and energy foundations. Buying, recovering, storing, fitting and recorded paid prerequisites remain distinct. Use Equipment (3) at a main orbital station and Inventory (9) for owned items and painted fitting reviews; RRS docks have no general equipment shop.

## Stock grades

| Navigation | Stock jump reach | Search scope | Acquisition |
| --- | ---: | --- | --- |
| Basic | 7 LY | Fuel capacity plus 7 LY | Included foundation |
| Intermediate | 14 LY | Fuel capacity plus 14 LY | 3,000 CR stock module |
| Advanced | 21 LY | Entire current galaxy | 9,000 CR stock module |

Actual jumps use the fitted reach, current fuel and effective fuel cost. Compatible improvements can change reach, spool time and fuel cost. Search uses installed fuel capacity and the fitted grade; browsing or setting a route does not launch or jump. The old saved Navigation: Advanced identity maps to Intermediate, and Navigation: Military maps to Advanced. Their persisted IDs are retained.

| Energy | Stock capacity versus hull base | Stock recharge versus hull base | Acquisition |
| --- | ---: | ---: | --- |
| Basic | 1 | 1 | Included foundation |
| Intermediate | 1 | 2 | 1,500 CR; legacy Extra Energy Unit |
| Advanced | 1 | 3 | Naval mission reward, XYZZY or PLUGH; legacy Naval Energy Unit |

| Shield | Stock front/rear capacity versus hull base | Stock recharge versus hull base | Acquisition |
| --- | ---: | ---: | --- |
| Basic | 1 | 1 | Included foundation |
| Basic II | 1.5 | 1 | 300 CR |
| Intermediate | 1.8 | 1 | 600 CR |
| Intermediate II | 2 | 1 | 750 CR |
| Advanced | 2.3 | 1 | 4,500 CR |
| Advanced II | 6.9 | 1 | Elite-rank Capital reward, XYZZY or PLUGH |
| Elite | 9.2 | 1 | Compatible recovered-upgrade progression; no ordinary shop row |

Prices are base stock prices before station discounts and availability rules. Actual capacities and recharge multiply the hull's native values. The Elite combat-rank reward supplies the preserved Capital item, now stock Advanced II; the Elite component grade is a separate threshold. Current XYZZY supplies that Advanced II stock shield, the Advanced navigation module and Advanced energy module. It does not manufacture recovered-upgrade history.

## Applying upgrades

A compatible recovered upgrade changes the selected physical component and is consumed once. Its effect is a finite percentage of that component's immutable original statistics, added to current statistics. Two distinct compatible +10% items therefore add 20% of the origin for that axis; they do not multiply the already improved value. The same item cannot be replayed.

The component retains its identity, origin, accumulated improvements, features and receipts. Meeting every required threshold promotes its grade automatically, retaining excess progress; one application may cross multiple grades. An improvement to another axis can remain useful without completing the next grade. A new stock purchase is a separate owned item; a weaker purchase is stored rather than replacing stronger fitted statistics. One component occupies each shield/navigation/energy slot, while applied upgrades accumulate on that component.

New improvements stop at family terminal envelopes: shield capacity ratios 11.96 and recharge 1.3; navigation reach 27.3 LY with spool/fuel-cost ratios no lower than 0.7; energy capacity ratio 1.3 and recharge 3.9. Valid grandfathered statistics are preserved rather than clipped to these bounds. Fitting, capacity and custody rules still apply. A successful fit/promotion preserves current resource fractions and does not refill energy, shields, fuel or missiles.

## Legacy compatibility and validation

Saved laser-named shield keys remain readable. Their actual old strengths are retained: legacy Mining's 5× shield is reconciled to the Advanced grade with excess progress, and legacy Beam's 1.5× strength maps to Basic II. Those historical values differ from newly purchased Intermediate and Intermediate II stock; migration does not weaken an old component to match a renamed shop row. Legacy reward identities, legal/mission progress and paid history remain intact.

Source authorities are [module templates](../Sources/EliteCore/EquipmentModuleTemplates.swift), [purchase identities](../Sources/EliteCore/EquipmentPurchaseProgression.swift), [runtime fittings](../Sources/EliteCore/EquipmentRuntimeCatalog.swift) and [upgrade progression](../Sources/EliteCore/ComponentProgression.swift). This guide describes implemented source; final composed CI/release acceptance is tracked in the [qualified ledger](WHOLE-APP-REMEDIATION.md). It does not claim these development changes shipped in the published 1.4.0 app.
