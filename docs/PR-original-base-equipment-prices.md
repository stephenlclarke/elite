# Apply approved base equipment prices through the existing shop authority

Twelve Equipment.base prices now use the approved CR values converted exactly to integer tenths. The existing shopPrice, purchase context, sealed equipment quote, actual debit, fuel refill and equipment readout continue to share that authority. The shared paid G03 preparation also resolves each fixed-fit price from this same catalogue/shop authority instead of retaining a stale second price table. Its atomic transaction and fitting checks remain.

## Adopted table and supersessions

Source: the private `original-world-economy/equipment.toml` in the 13 October approved-content workspace, also preserved as `Universe.originalWorlds.authoring.equipment` in bundled `Resources/OriginalWorlds/authoring.toml`. Root adopted the twelve non-energy prices on 24 October. The resource's private-proposal status is retained; resources and fingerprints are unchanged. Later energy revision 2 and [stock energy documentation](EQUIPMENT-MODULES.md) supersede the two energy proposals.

| Item | Proposal CR | Effective tenths CR | Disposition |
| --- | ---: | ---: | --- |
| Fuel | 1.8 | 18 | Adopt price; preserve native fuel count semantics |
| Missile | 180 | 1800 | Adopt price only |
| Large Cargo Bay | 2800 | 28000 | Adopt price only |
| E.C.M. System | 2100 | 21000 | Adopt price only |
| Pulse Laser | 1450 | 14500 | Adopt price only |
| Beam Laser | 4700 | 47000 | Adopt price only |
| Fuel Scoops | 1900 | 19000 | Adopt price only |
| Escape Pod | 3600 | 36000 | Adopt price only |
| Energy Bomb | 12800 | 128000 | Adopt price only |
| Extra Energy Unit | 7200 | 15000 | Later Intermediate stock module wins; unchanged |
| Galactic Hyperdrive | 28500 | 285000 | Adopt price only |
| Mining Laser | 3300 | 33000 | Adopt price only |
| Military Laser | 16400 | 164000 | Adopt price only |
| Naval Energy Unit | 19600 | 45000 | Later Advanced stock module wins; unchanged |

The Fuel resource declares no quantity unit. This packet preserves the existing native missing-fuel-count multiplication and only converts CR to tenths. PLUGH discounts the whole refill once: seven missing units cost 126 tenths ordinarily and 95 at PLUGH. Naval Energy retains the 45000 reward-shop base and 33750 discounted total. Reward availability, stock, prerequisites, displayed/stored technology, laser damage/rate, missile damage, module recharge, Elite Energy, cabin prices and persistence are unchanged.

ShieldBooster.shopItem already computes named-laser price times three quarters. Its four ordinary prices consequently become 10875, 24750, 35250 and 123000 tenths, with no shield source/mechanics change. Their independent sum is 193875. The two existing purchase fixtures now start with 232375 to retain the original 38500 remainder; their fitting, stored legacy strength, provenance, order and refusal assertions stay intact. The existing fuel/missile/cargo purchase scenario now has a 3000-tenths test budget: ten fuel units cost 180, leaving 2820, then one missile costs 1800, leaving 1020. Its separate 100000-tenths cargo-bay purchase leaves 72000. All rack, refusal, ownership, flight and capacity assertions remain; a selected wrapper runs this original scenario. Only actual Mining Laser debit expectations change to 33000. Targeting Basic's legitimate 8000 and the separate deliberately forged Targeting price remain unchanged.

## Validation and handoff

Five new selected methods exercise all twelve ordinary/PLUGH rows through real price readouts and mutation intents, exact sealed quotes/debits, once-only replay refusal, insufficient funds/forged-price refusal, preserved energy overrides and derived shield purchase joins. One method delegates both original shield scenarios without replacing their assertions. Three existing equipment-runtime methods cover five Mining Laser purchases, separate work-tool/storage debits and shield resource-fraction preservation. Four existing G03 methods additionally retain real paid preparation, unavailable-shop, insufficient-budget and altered-world rollback checks. All 529 inherited selected methods remain, plus twelve for 541 total. Argument expansions are reported by the actual hosted result rather than inferred as a pass.

Strict Swift formatting, Markdown and whitespace checks pass; twenty Python isolated-report fixtures pass. No local compiler, Swift test, native journey, GUI or performance job ran. Hosted Swift execution and independent MBA bugs/performance/style review are pending. This packet is stacked separately on frozen M03 source `2623e269`; M01 merge hold remains. Existing source qualification and performance branches are preserved. This is not full M03 completion or a release claim. See [the issue note](ISSUE-original-base-equipment-prices.md).

## Confirmed correction scope: issues 225, 226 and 227

The actual `04aa01c8` hosted result completed all 537 methods: 525 clean, twelve failed with 31 issue records. MBA retained the sole artifact and filed [225](https://github.com/stephenlclarke/elite/issues/225), [226](https://github.com/stephenlclarke/elite/issues/226) and [227](https://github.com/stephenlclarke/elite/issues/227). No crash or corrected aggregate pass is claimed. The descendant technology result has exactly the same inherited failures; its three new technology methods separately passed.

The new price fixture incorrectly searched Galaxy 1 for TL19: that is the whole-catalogue maximum, while Galaxy 1 stops at TL17. It now selects the highest actual ordinary world in its existing galaxy, preserving identity, all parameter cases and every blocked purchase/readout assertion.

G03's fixed five purchases remain ordered and atomic. Prices and total debit now come from actual catalogue/shop quotes, with the same whole-candidate publication and owner/fit/cargo/fuel/flight checks. Independent receipt tests pin 8000 + 20000 + 40000 + 10875 + 15000 = 93875, leaving 6125 from the unchanged production 100000 budget. The directly affected preparation threshold and station fixture balance follow that math. Optional Escape Pod setup belongs only to a freight test fixture: Root separately authorized adding its actual quoted 36000 accessory budget to that fixture's 100000 base, then making a fresh real paid purchase. Its history must show all six purchases and the same 6125 remainder; no production trial grant, free fitting or missing escape requirement changes.

Fuel requests already use the approved 18-tenths price. Exact independent oracles now require 90 units cost 1620 and leave 8380, while the rounded eight-unit partial refill costs 144. The unchanged finite 10000 escrow supports six 1620 purchases, leaves 280, and refuses the seventh. Distinct source/stock identities, escrow separation, stale/foreign refusal, closed decode and balance-tamper assertions remain.

Static affordability bound from immutable catalogue coordinates: direct G01-S211 to G01-S000 is 10.688086 LY, and G01-S154 supplies two valid legs of 6.4357461541 and 6.8381995788 LY at the supplied 7-LY reach. The production route chooses fewest hops with edge cost one, so its route has two legs. Even from empty, each needed-hop purchase bills at most 70 native tenths: `2 * 70 * 18 = 2520`, below the unchanged 10000 rescue escrow. This is a financial bound, not proof of stock availability, actual docking, launch or journey completion. No native run or benchmark produced it.
