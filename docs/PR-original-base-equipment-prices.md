# Apply approved base equipment prices through the existing shop authority

Twelve Equipment.base prices now use the approved CR values converted exactly to integer tenths. The existing shopPrice, purchase context, sealed equipment quote, actual debit, fuel refill and equipment readout continue to share that authority. No production consumer or transaction algorithm changes.

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

ShieldBooster.shopItem already computes named-laser price times three quarters. Its four ordinary prices consequently become 10875, 24750, 35250 and 123000 tenths, with no shield source/mechanics change. Their independent sum is 193875. The two existing purchase fixtures now start with 232375 to retain the original 38500 remainder; their fitting, stored legacy strength, provenance, order and refusal assertions stay intact. Only actual Mining Laser debit expectations change to 33000. Targeting Basic's legitimate 8000 and the separate deliberately forged Targeting price remain unchanged.

## Validation and handoff

Four new selected methods exercise all twelve ordinary/PLUGH rows through real price readouts and mutation intents, exact sealed quotes/debits, once-only replay refusal, insufficient funds/forged-price refusal, preserved energy overrides and derived shield purchase joins. One method delegates both original shield scenarios without replacing their assertions. Three existing equipment-runtime methods cover five Mining Laser purchases, separate work-tool/storage debits and shield resource-fraction preservation. All 529 inherited selected methods remain, plus seven for 536 total. Argument expansions are reported by the actual hosted result rather than inferred as a pass.

Strict Swift formatting, Markdown and whitespace checks pass; twenty Python isolated-report fixtures pass. No local compiler, Swift test, native journey, GUI or performance job ran. Hosted Swift execution and independent MBA bugs/performance/style review are pending. This packet is stacked separately on frozen M03 source `2623e269`; M01 merge hold remains. Existing source qualification and performance branches are preserved. This is not full M03 completion or a release claim. See [the issue note](ISSUE-original-base-equipment-prices.md).
