# Commies Minnow, Ray Mk I and Military Stingray specifications

SH168, SH169 and SH170 close three additional whole-hull identity/player/crew gaps. [Selected mechanics](data/commies-selected-ship-mechanics.json), [common research profiles](data/player-ship-adaptation.json) and [crew profiles](data/ship-crew-profiles.json) keep source configurations, player conversions, borrowed engine defaults and estimates separate. The research catalogue now has170 canonical records and161 filled common player refits. These are research inputs: authoritative runtime definitions remain the individual ship TOMLs described in [the actual ship format](../SHIP-FILES.md). Adding these JSON records does not install or make the three ships playable.

Apply [scope v4](implementation-scope.md), [crew/passenger rules](crew-and-passenger-specifications.md), [shipyard/storage/linked comparison](player-shipyard-design.md) and the [pack handoff contract](runtime-pack-handoff-contract.md). The first two hulls are already used by the completed [Astromine4b mission](rescue-astromine-mission-specifications.md); filling their player conversions does not change their mission NPC stats, crew custody or AI. Military Stingray is an additional distinct source hull recovered during this closure, not another Astromine mission.

## Sources, versions and identity

Primary source is [Commies2.20](https://wiki.alioth.net/img_auth.php/3/3c/Commies_2.20.oxz),35340515bytes, SHA25609d478852cf2485e3a1e8be2ebca9d8771ea13af08ac977010a7c07fb8a42e4a. Config/shipdata, shipyard, shiplibrary, README, manifest and condition script establish the values and variant relationships. [Author package page](https://wiki.alioth.net/index.php/Commies) corroborates release context. P30 Rescue Stations1.5.4 supplies the RRS compatibility wrappers, pinned separately in Astromine mechanics. These current dependency models are not an assertion of exact2017 assets or binary parity. Native readers use [O08 commit574ca848c91a067178416216523e8d09c1e9282a](https://github.com/OoliteProject/oolite/tree/574ca848c91a067178416216523e8d09c1e9282a).

| Canonical identity | One selected model | Source variants retained | Selected common player basis |
| --- | --- | --- | --- |
| SH168 Convict Miner Minnow | commies_comminer.dat | comminer, escaping comminer-escapee, P30 rrs_astrominer_commies | Explicit NPC-to-player conversion of ordinary Minnow |
| SH169 Ray Mk I | commies_ray.dat | People's Police comviper, Thought Police politicop, astromine-defender, Convict Miner Ray comminer2, Sunray/sunray-player, P30 rrs_astroguard_commies | Verified native civilian sunray-player outfit |
| SH170 Military Stingray / Ray Mk II | commies_rayii.dat | commilray, commilray-player, slapu-defender | Verified native commilray-player outfit |

Thirteen dictionaries map to three hulls. Police/Thought Police/Miner/Sunray paint and fitting differences do not create extra Ray Mk I hull IDs. Ray Mk II has its own model and mark, so it remains separate. Neither is the Commies Giant/Manta Ray carrier or an Aquatics Manta Ray. The source key comviper is not evidence that the hull is a GalCop Viper mesh. Stations, docks, flashers and missiles are not new crewed hulls. No alien identity is added by these craft or political descriptions.

The package README records replacement ship graphics in2.18 and a Military Stingray player-shipyard entry added in2.19. Only the selected2.20 models/statistics are asserted here. The unversioned [Ray Mk I page](https://wiki.alioth.net/index.php/Ray_Mk.I) gives41x11x47 dimensions, differing from the selected mesh. The unversioned [Military Ray page](https://wiki.alioth.net/index.php/Military_Ray) also gives that older size, recharge4, two missiles and no player availability; selected2.20 code has a distinct larger model, recharge6, three missiles and a player offer. Preserve those discrepancies as reference; do not average values or backdate the current player offering. The native police Ray still has no player sale; Sunray is its separately configured civilian sale.

Commies source-model terms are CC BY-NC-SA3.0 per manifest/README; original creator/version/model hashes remain in mechanics. The numerical/source records are not a change to those terms. Original source models remain in the external research cache; coder import must preserve exact custody/attribution/original notices in each authoritative TOML and generated appendix.

## Filled common player values

Values below are common O08-style research units, before the existing native game's separate Cobra calibration. Required docking computer/drive/operating quarters are intrinsic. Source NPC variants never inherit these new player minima. Every conversion or missing-field default remains individually labelled in JSON.

| Property | SH168 Minnow | SH169 civilian Sunray | SH170 Military Stingray player |
| --- | --- | --- | --- |
| Standard hold before fitted cabins | 0t | 10t | 15t |
| Optional fitted extra hold | 0t | 0t | 15t |
| Maximum speed | 240 | 390 | 430 |
| Thrust input / converted acceleration | 12 / 60 | 50 / 250 | Missing native default15 / 75 |
| Roll / pitch / yaw radians per second | 1 /0.5 /0.5 | 2.8 /2.1 /2.1 | 2.8 /2.1 /2.1 |
| Base hull energy / recharge | 25 /1 | 300 /3.5 | 275 /6 |
| Borrowed fore/aft shield maximum | 128 /128 | 128 /128 | 128 /128 |
| Borrowed fore/aft shield recharge per second | 2 /2 | 2 /2 | 2 /2 |
| First forward weapon | Mining laser | Beam laser | Beam laser |
| Enabled facing mask | 1, selected conversion | 1, native player yard | 1, native player yard |
| Forward emitter count | 1 | 1 | 2, multiply mode |
| Pylons / first missile stock | 1 /1, owner conversion minimum | 1 /1 | 3 /3 |
| Common equipment budget | 8, estimated | 10, estimated | 11, estimated |
| Fuel capacity / range / spool | 70tenths /7LY /15s | Same | Same |
| Player scanner range | 25600 | 25600 | 25600 |
| Operating crew including commander | 1, estimated | 1, estimated | 1, estimated |
| First fitted passenger berths | 0 | 1, verified source-standard module | 0 |

Known native zero Minnow hold is adopted for the conversion, not replaced with a volume guess to make passenger jobs work. Its source has no player sale or pylon, so the required one-pylon/one-missile player minimum is explicit. No hold expansion is invented. Its existing forward mining laser satisfies the owner's forward-laser baseline. The P30 escaped NPC's hyperspace_motor0 remains0; ordinary Minnow lacks that key and uses native motor defaulttrue but starts with missing fuel0. Those are different configurations of the same hull, not a grant of70fuel to the rescued NPC.

Sunray's native10-tonne hold and its explicit first fitted berth are separate. The berth reserves5tonnes, leaving5 usable tonnes in its first standard fit. Native price300000credits/chance0.01/techlevel7 are preserved as historical offer metadata, not adopted native-game economics. Its optional list does not contain cargo-bay expansion; common extra hold is0 despite the engine's otherwise unused missing-extra_cargo default15. Standard extras are heat shield, fuel scoops and the passenger berth, plus the owner's intrinsic docking/drive. NPC inherited ECM is not an extra unlisted standard player item.

Military Stingray's player yard selects beam despite the NPC's military laser. Standard extras are ECM and scoops; price450000/chance0.1/techlevel7 remain historical metadata. The optional list explicitly includes cargo bay; missing extra_cargo uses native15 and gives30t only when the expansion is fitted. Missing thrust uses15, not the related police Ray's50: the military definition has no like_ship parent supplying it. Acceleration borrows the verified O08 factor5. Source raw NPC fuel160 is not a16LY capacity: default ordinary engine fuel capacity is70, and common player capacity/range remain70/7. Do not silently convert that anomalous NPC initial stock into a larger player tank or range.

Native player setup creates ordinary EQ_MISSILE for these standard stocks; Ray/Sunray NPC missile_role EQ_HARDENED_MISSILE does not grant hardened player rounds. First stock and source extras are first-acquisition template information with unique item receipts, not repeated selection/exchange rewards. The current native exchange carries the commander's existing fit and gives no starter stock; a future template/outfit adapter must distinguish a genuine first acquisition from switching an existing owned fit.

## Weapons, mounts and exact limits

Each enabled facing has one uniquely owned weapon controller. Stingray's multiply mode maps that one forward controller to the two intrinsic source muzzles(7.7,0.05,21.3) and(-7.7,0.05,21.3). They fire the same selected weapon; they are not independent slots for two different laser types and do not create a second inventory module. A donor hull's incompatible rear/side controller goes to persistent storage, not into a fictitious second forward equipment slot.

Pinned source beam values per emitter are damage6, energy use0.5, heat3.2, nominal recharge0.1seconds and range15000. Native multiply mode charges use/heat times emitter count and keeps full damage per ray: Stingray's two beams cost1energy/add6.4heat and can deal12 if both rays hit the same target. Rays trace separately and may miss/hit different objects; do not award12 unconditionally to one target. Energy must be strictly greater than the combined cost. Player controls separately require shot_time strictly greater than recharge time; frame cadence, temperature cutout and shared cooling still apply. Oolite theoretical dual-beam damage rate is not the current native game's calibrated weapon damage by inference.

NPC Stingray military lasers use the separate native military record:12damage/1.1energy/4.25heat per emitter, range30000 and nominal0.1recharge. The common player starts with the yard's beam. Minnow's native mining laser uses50damage/1.4energy/10heat, range12500 and2.5recharge. Its legacy shipdata weapon_energy1 does not override an already nonzero current laser damage; the pinned reader and firing path establish this. A raw dictionary scalar1 is not a recovered one-damage mining beam.

[Twenty C/Python cases](data/commies-multiweapon-verification.json) independently check selected strict-energy and damage/use/heat expressions, with lane timings. They use synthetic doubles and do not prove original float precision, hits, range, temperature, cadence or native game integration. Native ship support must implement and test the controller/muzzle semantics explicitly, rather than inserting unrecognised TOML game keys that the current schema does not use.

## Native role variants remain distinct

Police/defender Ray uses4t, speed400,300energy/recharge4, beam/ECM/scoop and one hardened missile. Convict Miner Ray uses16t,250speed,150energy/recharge1, no forward weapon/ECM/missiles, while keeping the Ray model/handling. Civilian Sunray uses10t,390speed,300/3.5 and its own fit. Escaping Minnow changes speed240->270 and bounty0->200; P30 gives its protected mining craft no own hyperspace motor and mission-specific AI. P30 guards explicitly use accuracy-5. Native police defaults, autoAI/conditions and actual spawn-time fuel/bounty grants remain in their own source runtime, not the player's conversion layer.

The source condition script admits NPC spawn in government4 or with the population override. It must not delete an already owned player hull when travelling elsewhere or prevent save restoration of the same escaped NPC at home. Player selection never installs prisoner/Thought Police/SLAPU scripts, changes commander law/reputation, seizes passengers or grants NPC police authority. The existing Astromine mission uses its exact NPC variants and actual pilot/agent receipts; it must not spawn the common player Sunray or a newly armed/jump-capable Minnow in their place.

## Geometry, crew and passenger fit

| Hull | Exact selected envelope X/Y/Z | Envelope box volume | Interpretation |
| --- | --- | --- | --- |
| Minnow | 7.8576 /5.6 /23.41789 | 1030.4471097983999 | Tiny piloted mining craft, source zero hold |
| Ray Mk I | 43.1004 /7.3 /52.05 | 16376.643485999999 | Shared police/miner/civilian mesh |
| Military Stingray | 51.23331 /9.21302 /70.05798 | 33068.31302202618 | Distinct Ray Mk II mesh |

Exact min/max/model hashes and independent vertex re-parses are in mechanics. AABB is an envelope/proxy, not a measured usable interior, closed hull volume, SI scale or octree docking clearance. It supplies a reproducible crew size input without inventing a cargo percentage where selected capacity is already known. The native implementation currently normalises visual models and uses point docking; exact source-scale docking must not be claimed from that abstraction. Retain raw shape/provenance in design custody and state the chosen game scale/physical adapter explicitly.

No numerical operating complement was established in the selected dictionaries, readme, library or consulted ship profiles. All three selected complements are therefore labelled estimates using the established formula with measured volume divided by369874.0268262 and the8/10/11 equipment budgets plus0/10/15 holds. Each yields1including commander. The reserved operating quarter is intrinsic and outside published usable hold; it is not a spare charter place or another five-tonne deduction. The abstract assigned operating complement requires no new hiring/salary UI.

CREW07 adds one verified edition fact: Sunray-player explicitly supplies one fitted passenger berth. This is the named source-standard exception to the general first-berths0 default, not an estimate from a crew seat. In the common adapter it is one uniquely owned module costing5tonnes and1equipmentunit, with one receipt on genuine first acquisition. Its heat/scoop modules cost two other units, so first fit uses3of10units and5of10hold tonnes. It can take one compatible passenger and5t ordinary cargo, but6t cargo fails. Installing a second real berth can use the other5t; the first does not imply two places. Storing an empty berth releases its costs while retaining that exact module; an occupied berth cannot be stored.

Minnow has no ordinary passenger berth capacity in its zero hold. Stingray has no free initial cabin; explicitly fitting three berths consumes15t/3units plus its two standard modules. With the real15t expansion fitted, its two standard modules plus expansion cost3units, and six berths consume30t/6units. Any additional cargo prevents that full fit. These ceilings are common-project accounting examples, not historical native passenger maxima. Source medical supplies6a can only load the actual usable hold after fitted cabins; changing ships cannot multiply an already loaded consignment.

## Mapping into the actual runtime format

The inspected14October2026 format is [CatalogueShip/ShipProfile/ShipSpec](../../Sources/EliteCore/ShipCatalogue.swift) with the17 [ShipPerformance](../../Sources/EliteCore/ShipPerformance.swift) game fields. The `[design]` numerical geometry/custody and `[[profiles]]` source facts belong in the corresponding individual authoritative SH168/SH169/SH170 TOMLs. There is no competing research TOML schema. The source common JSON remains evidence input and must not override the native maintained game values of existing ships.

Mechanics supplies proposed initial game values for these new IDs under the existing documented calibration. They are a reviewable native adaptation, not original Oolite stats or source prices. Core differences are speed21.943/35.657/39.314, acceleration4.5/18.75/5.625, energy25/300/275, recharge0.5/1.75/3, roll0.5/1.4/1.4 and pitch/yaw0.5/2.1/2.1. Holds0/10/15, fuel70, range7, spool15, pylons1/1/3, facings1 and expansion0/0/15 retain common meanings. Proposed formula prices65000/137000/153000 use the current native economics; coder review owns the actual game values. The existing game shield255/recharge1 anchors differ from source128/recharge2 and are labelled calibration, not another source fact.

Current runtime code does not have native fields/primitives for source crew, fitted cabins, equipment-unit budget, persistent surplus storage, first-acquisition source outfits or twin emitters. These source fields can be retained in inspectable profiles but are not automatically working mechanics. Add reviewed primitives/schema support before claiming a source-standard Sunray passenger place or a functioning two-emitter Stingray. Unsupported mission capabilities must keep associated contracts unavailable. Current trade blocks incompatible/excess gear rather than storing it; the owner's persistent-storage requirement remains outstanding and must preserve exact cargo/people/mission custody.

Update source/model notices, then use the actual existing `make ships`, `make ships-check` and `make ci` workflow for implementation. Each changed authoritative TOML drives its incremental rotating GIF and regenerated catalogue/provenance. Research-only edits here do not generate substitute GIFs or edit those maintained runtime files. README media remains renderer-generated with make readme-media. Once the coder establishes the external mission-pack schema, map source progression and capabilities to that schema; a data file cannot implement new AI, cargo, storage or physics code.

## Shipyard, gallery, save and acceptance

Show the three actual models in docked selection and aligned comparison with the same orientation/direction/plane/roll, full360-degree inspection, current/native versus source units and actual carried fit. Sunray's current usable5t after its actual source-standard berth is distinct from base10t; a source-only reference never becomes a working cabin. Distinguish crew1, fitted berths, occupied places, free places and equipment/hold costs. Show emitter count and real firing capabilities, rather than confusing two barrels with two owned weapons or two facings.

Transfer all compatible uniquely owned gear and store surplus for later reuse. An excess laser/missile/module can go to equipment storage only through an explicit implemented adapter; cargo, the captured pilot, agent, other passengers and fixed medical consignment cannot. Block insufficient real custody fit before confirmation. Preserve commander law/reputation, mission stage, exact IDs, cargo quantity, hull/item condition and spent stock. New acquisitions, bought exchanges, already owned inactive hulls and gallery templates have distinct receipts; source outfit or initial stock never repeats on simple reselection/load/Back.

Acceptance covers stable IDs/alias dedup, source version/role/native-player separation, known-zero hold, correct borrowed defaults/units, strict weapon energy and both rays/heat, source-standard berth versus crew, exact hold/equipment fit, occupied-cabin swap block, surplus storage/no destruction, no NPC authority/mission reassignment, actual navigation/fuel/route limits, source assets/custody/renderer/rotated-docking boundary, once-only first outfit, every-phase save/migration and isolated Mission Gallery/shipyard state. Astromine gallery must preserve actual SH168/SH169 NPC configurations. Native tests/rendering, TOML/media gates and new required capabilities remain implementation work; research verification does not assert that any new hull is currently playable.
