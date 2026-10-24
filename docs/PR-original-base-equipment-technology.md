# Apply adopted original equipment unlock levels at the existing boundary

Eleven Equipment.base technology arguments now store the approved displayed TL minus one. Fuel already stored zero and remains unchanged. Equipment.requiredTechnologyLevel, StarSystem's one-based original TL, equipmentAvailable, quote validation and refusal rendering keep their existing logic. Prices are byte-identical to parent price packet `3368697b`; no controller or transaction changes.

| Base item | Displayed TL | Stored technology |
| --- | ---: | ---: |
| Fuel | 1 | 0 |
| Missile | 2 | 1 |
| Large Cargo Bay | 4 | 3 |
| E.C.M. System | 5 | 4 |
| Pulse Laser | 3 | 2 |
| Beam Laser | 7 | 6 |
| Fuel Scoops | 4 | 3 |
| Escape Pod | 6 | 5 |
| Energy Bomb | 13 | 12 |
| Galactic Hyperdrive | 15 | 14 |
| Mining Laser | 6 | 5 |
| Military Laser | 14 | 13 |

Source is the same private original-world-economy equipment proposal retained in bundled OriginalWorlds authoring. Root explicitly adopted these non-energy levels on 24 October; this is a new precedence decision, not historical implemented authority. Later energy modules retain displayed TL9 (Extra), TL12 (Naval) and TL14 (Elite), with current prices/recharge/prerequisites unchanged. Ordinary shield stock TL continues to follow its named laser through the existing computed join. PLUGH's availability exception and paid predecessor checks are retained.

Three focused methods exercise actual original-world shop availability, quote/mutation refusal and displayed Requires TL text below the boundary, then successful quotes/purchases at it. The authored catalogue contains TL3 through TL19, so exact below/at world pairs exist for the nine affected-table items with TL at least four. Tests do not invent TL1/2 planets: Fuel, Missile and Pulse are checked against their independent TL1/2/3 oracle and actual availability/purchase at the lowest authored TL3 world. Later energy below-boundary checks, shield joins and PLUGH's retained prerequisites are explicit. No existing acceptance assertions are weakened or replaced.

All 541 corrected-parent selected methods remain; three are added for 544 total. Strict Swift formatting, Markdown and whitespace checks and twenty Python isolated-report fixtures pass. No local Swift compilation/test, native journey, GUI or performance job ran. Hosted exact-head execution and independent bugs/performance/style review are pending; no unit PASS or full M03/playable/release claim is made. The packet is stacked on the separately reviewed/pending price PR223 and retains the M01 merge hold. See [the issue note](ISSUE-original-base-equipment-technology.md).

Composition on reviewed parent correction `3368697b` resolves only the two additive selector/count conflicts and updates this note. The eleven TL arguments and three technology test methods are byte-identical to prior `f16737cb`. MBA verified those three methods PASS in the original 540-method run, whose twelve failures/31 issue records exactly matched the old parent. That failed aggregate remains explicit; the corrected composition has no aggregate PASS yet. No local test or native job was run for this composition.
