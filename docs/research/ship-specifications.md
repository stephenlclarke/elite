# Ship specifications and future player refits

This supplement separates original game capabilities from the project rules requested on 13 October 2026. Player ship switching must preserve known values and visibly identify estimates. Every playable refit has a docking computer, forward laser, hyperspace drive and capacity for at least one missile. These requirements apply to the project player profile; they do not rewrite historical NPCs or mission targets.

## Evidence and adaptation layers

| Value status | Meaning |
| --- | --- |
| Source | Directly extracted from an identified game/profile. Preserve source units and distinctions between NPC and player. |
| Derived | Calculated from established source rules, retaining the formula and inputs. |
| Borrowed | Adopted from another identified edition, such as Oolite, for the new game; not claimed to be an original capability. |
| Estimated | Project value based on geometry, reference hull or an explicit fallback. Confidence and method remain attached. |
| User required | The docking computer, forward laser, hyperspace drive and one-missile minimum requested for playable refits. |

The capability record needs separate base hull, supported slots/capacity, installed loadout and current condition. A maximum missile capacity is not the number currently aboard. Cargo space is not salvage count. Hull energy is not automatically a shield pool. A weapon type is not a complete damage/range/cadence specification.

## Oolite core and player profiles

O08 now supplies [all 194 core definitions](data/oolite-ship-specifications.json), including templates, stations, missiles, debris and components, eleven native shipyard entries and numerical bounds for 68 referenced model files. The dataset resolves core like_ship inheritance and retains each record's own fields. The existing [93 expansion definitions](data/oolite-combat-resources.json) additionally resolve their base references against this pinned core; no external base remains unresolved in those eight package revision profiles. Installed replacement expansions, population choices and runtime equipment can still change the result.

The table shows resolved player hull values. Laser and initial missiles are the shipyard standard loadout, which can differ from an NPC variant or a maximum. Speed/turn values retain the source engine units pending the chosen project conversion. Cargo is tonnes. Expansion is shown only when EQ_CARGO_BAY is offered by the native shipyard; the engine default extra_cargo parameter alone does not make the upgrade available.

| Player entry | Cargo / offered expansion | Speed | Energy / recharge | Missile capacity / stock | Stock forward laser |
| --- | --- | --- | --- | --- | --- |
| adder-player | 2 / not offered | 240 | 85 / 2 | 1 / 1 | EQ_WEAPON_PULSE_LASER |
| anaconda-player | 750 / not offered | 140 | 500 / 3 | 7 / 3 | EQ_WEAPON_PULSE_LASER |
| asp-player | 0 / not offered | 400 | 350 / 4 | 1 / 1 | EQ_WEAPON_PULSE_LASER |
| boa-mk2-player | 175 / not offered | 312 | 525 / 3.2 | 5 / 5 | EQ_WEAPON_BEAM_LASER |
| boa-player | 125 / not offered | 240 | 450 / 3 | 4 / 3 | EQ_WEAPON_PULSE_LASER |
| cobra3-player | 20 / +15 | 350 | 256 / 4 | 4 / 3 | EQ_WEAPON_PULSE_LASER |
| cobramk1-player | 10 / not offered | 260 | 150 / 2.5 | 1 / 1 | EQ_WEAPON_PULSE_LASER |
| ferdelance-player | 12 / not offered | 300 | 150 / 4.5 | 2 / 2 | EQ_WEAPON_BEAM_LASER |
| moray-player | 7 / not offered | 300 | 240 / 3 | 2 / 2 | EQ_WEAPON_PULSE_LASER |
| morayMED-player | 7 / +15 | 300 | 240 / 3 | 2 / 0 | EQ_WEAPON_NONE |
| python-player | 100 / +15 | 200 | 450 / 2.5 | 2 / 1 | EQ_WEAPON_PULSE_LASER |

PlayerEntity initializes fore and aft shields to 128 each, with recharge 2 each. equipment.plist and oolite-equipment-control.js define the player shield upgrades: Shield Booster adds 128 to each pool; Military Shield Enhancement adds another 128 and multiplies recharge by 1.5. NPC ShipEntity instead adds 256 to energy for each corresponding upgrade and multiplies energy recharge by 1.5 for the enhancer. Copying NPC energy into a player shield field would therefore change the rules. Energy-unit multipliers are 1.8 and 2.6; the control script applies their changes relative to its saved baseline.

| Laser equipment | Damage | Range | Energy per shot | Recharge parameter | Heat per shot |
| --- | --- | --- | --- | --- | --- |
| EQ_WEAPON_NONE | 0.0 | 32000 | 0.0 | 100.0 | 0.0 |
| EQ_WEAPON_PULSE_LASER | 15.0 | 12500 | 0.8 | 0.5 | 7.0 |
| EQ_WEAPON_BEAM_LASER | 6.0 | 15000 | 0.5 | 0.1 | 3.2 |
| EQ_WEAPON_MINING_LASER | 50.0 | 12500 | 1.4 | 2.5 | 10.0 |
| EQ_WEAPON_MILITARY_LASER | 12.0 | 30000 | 1.1 | 0.1 | 4.25 |
| EQ_WEAPON_THARGOID_LASER | 12.5 | 17500 | 1.1 | 1.0 | 8.0 |

These are equipment weapon_info parameters. A comment in currentWeaponStats claims weapon_recharge_rate is unused by the player, but the executable control path contradicts it: PlayerEntityControls polls firing only when shot_time > weapon_recharge_rate, and ShipEntity setWeaponDataFromType loads that value from the equipment. Preserve the strict comparison. fireMainWeapon rejects offline/no weapon, heat >=85% of 256, or energy <= per-shot use times the simultaneous-barrel count. A successful shot consumes that energy, adds per-shot heat times the barrel count and resets the corresponding facing's elapsed shot timer. All four facings cool by 6 * delta_t, floored at zero, and their timers advance by delta_t. The numerical recharge parameter therefore matters, but its reciprocal is only an ideal interval limit; input polling, heat, energy and barrel count constrain actual DPS. NPC auto_weapons and fuzzy equipment fields also prevent treating one dictionary as every spawned loadout. ShipEntity clamps NPC missiles to 32; PlayerEntity clamps player capacity to 16. A new game may choose another limit explicitly.

Player shield recharge first adds generator energy times delta_t. It computes each shield's potential recharge, limited by its missing capacity. If both shields are above 25% of their maxima, available recharge energy is max(0, energy -0.1 -maxEnergy*threshold), where the settings threshold defaults to 0.25; otherwise all current energy is available. The lower absolute shield receives priority, with aft winning an equality, and the other receives the remainder. Recharge drains the same amount from energy; shield and energy values are then clamped. These operations are source rules, not independent hull fields. Equipment-control applies player upgrade effects and NPC equipment uses the separate rules above.

## Elite-A player capabilities

S45 is the pinned Angus Duggan/Mark Moxon source, commit 75433e92e4914f970b14132fce6c8da68da5692f. [Extracted tables](data/elite-a-ship-specifications.json) preserve both released and source-disc/bug-fix index orders. All fifteen ships have actual player capability records. The released order swaps Fer-de-Lance/Ghavial and Asp/Anaconda relative to the other profile. Never identify a hull from its numeric index without the build profile.

| Ship | Hold including equipment | Missiles maximum | Speed raw | Per-hit absorption | Range LY | Laser mounts |
| --- | --- | --- | --- | --- | --- | --- |
| Adder | 8 | 1 | 36 | 4 | 6.0 | 2 |
| Gecko | 9 | 2 | 45 | 5 | 7.0 | 4 |
| Moray Star Boat | 11 | 2 | 38 | 6 | 8.0 | 4 |
| Cobra Mk I | 14 | 3 | 39 | 5 | 6.0 | 4 |
| Iguana | 21 | 3 | 50 | 7 | 7.5 | 4 |
| Ophidian | 24 | 2 | 51 | 4 | 7.0 | 1 |
| Chameleon | 35 | 3 | 43 | 8 | 8.0 | 2 |
| Cobra Mk III | 42 | 4 | 42 | 7 | 7.0 | 4 |
| Fer-de-Lance | 9 | 3 | 45 | 8 | 8.5 | 4 |
| Ghavial | 55 | 3 | 37 | 9 | 8.0 | 4 |
| Monitor | 81 | 8 | 24 | 10 | 11.0 | 4 |
| Python | 106 | 4 | 30 | 11 | 8.0 | 4 |
| Boa | 132 | 6 | 36 | 10 | 9.0 | 2 |
| Asp Mk II | 6 | 1 | 60 | 10 | 12.5 | 1 |
| Anaconda | 253 | 16 | 21 | 13 | 10.0 | 4 |

The source raw missile and hold entries are exclusive limits: subtract one to obtain capacity. Elite-A shields subtract a per-hit amount; that is not Oolite's rechargeable 128-point pool. The dataset also contains four encoded laser strengths, recharge and turn parameters. Original ship buying clears fitted equipment and missiles; the project's transfer/storage rules deliberately replace that behaviour.

## GBA definitions and original combat distinctions

[GBA extraction](data/gba-ship-specifications.json) contains all 38 SHIP_DATA records and numerical vertex envelopes. It includes object and role records, not 38 unique player ships. max_loot is a random salvage mask; swat.c applies a random count AND that mask. front_laser identifies the model's firing vertex, while laser_strength supplies NPC damage. The original player Cobra has speed 32, hold 20 tonnes or 35 expanded, fore/aft shields 255 each and energy 255. NPC energy values are independent.

Player laser codes are pulse 0x0F, beam 0x8F, military 0x97 and mining 0x32. fire_laser removes the high beam bit, sets the counter, adds heat 8 and uses one energy per successful shot only while energy >1; it can fire without that deduction at energy 0 or 1. cool_laser reduces heat and the fire counter on the game loop. Shields regenerate on mcount&7==0: with energy above 127 each damaged shield gains one while consuming one energy, then energy regenerates by one plus equipment bonuses and clamps at 255. These are loop counts, not seconds. The Constrictor/Cougar damage path accepts military lasers and subtracts military strength shifted right two; ordinary targets subtract the strength after the high beam bit is removed. Preserve these mission-specific immunities separately from a general player refit.

## Estimating missing player capabilities

The [project adaptation dataset](data/player-ship-adaptation.json) records the user baseline, all 164 catalogue rows' refit scope and 27 provisional GBA craft projections. Twenty-five projections have canonical IDs; Bushmaster and Passenger Shuttle retain their source identities pending exact design mapping. They remain separate examples. The dataset now also contains complete_project_profiles for all 155 current whole-craft catalogue rows, with fields filled and individually labelled; this does not establish historical parity or exact geometry. Stations, factories, satellites and components remain encounter objects; whole craft, including alien ships and capital ships, are in the player-refit research scope. An escape craft conversion is explicitly an adaptation.

Use known player data first. If absent, consult that edition's actual capacity/physics rules, then an identified Oolite player equivalent. Values borrowed across editions retain their origin. If usable cargo space remains undefined, estimate from a hull volume and a calibrated reference. The provisional hold fraction is **25%**. With only a bounding box, estimate hull occupancy as **35% of the box**, label that assumption and retain the dimensions. These percentages are project defaults selected for this pass, not historical facts.

Cargo estimate in tonnes: `floor(C_ref * (f_hold/f_hold_ref) * (f_shape/f_shape_ref) * (V_box/V_box_ref))`. The initial GBA reference is its player Cobra Mk III's 20-tonne standard hold and the matching source envelope. With equal fill/hold fractions this simplifies to `floor(20 * V_box/V_box_ref)`. A bounding box is an envelope, not internal volume. Volume cannot directly determine tonnes without this packing/mass calibration. Use a verified closed hull volume when available. Retain linear scale: doubling all dimensions multiplies volume and this estimate by eight. Do not use collision radius or a two-dimensional silhouette as cargo volume.

Known zero player capacity stays zero. An NPC-only zero cargo field does not prove that a newly designed player refit has zero usable hold. Overflow equipment consumes the slots/space specified by the chosen project rules and goes into storage. Reserve mandatory systems before calculating usable cargo; prevent counting the same equipment space twice.

The numerical GBA examples borrow Oolite's 128/128 player shield baseline and pulse-laser equipment. They map native velocity to a provisional project scale using a 300-unit Cobra reference and its source player speed 32. Other ships' NPC velocity parameters are used as estimates of their player performance. NPC energy is retained as a proposed hull value, with its origin visible. Missing GBA refit range is provisionally seven light years, borrowed from its player Cobra; shield recharge is borrowed separately from Oolite. The estimated cargo bay already reserves the hull fraction outside that bay for mandatory systems, so do not deduct them a second time. These are design conversions, not recovered SI measurements. Preserve missile capacity and stock separately: a zero-missile NPC gains at least one player pylon and one initial missile in the project profile. Re-selecting an existing owned ship must not refill spent missiles or duplicate baseline equipment.

When a hull has no reliable geometry, do not publish a fabricated volume as measured. Retain a low-confidence reference-hull estimate with the surrogate named, or leave that projection pending until a model is selected. Every ship needs dimensions/volume method, cargo, speed/acceleration/turning, hull/energy/shields/recharge, weapon mounts and equipment compatibility, missile capacity/loadout, fuel/range and docking envelope before final balancing.

## Persistence and implementation acceptance

Changing player hull must preserve commander identity, balances, reputation, mission flags, cargo/passenger identities and unique equipment instances. Apply the project baseline through a player-refit layer so original mission NPCs retain their source rules. Keep the selected profile, estimate provenance and item ownership in saves. The [shipyard design](player-shipyard-design.md) defines preview, comparison, transfer, storage and atomic confirmation.

Validate source record counts, capacity-versus-stock, source-unit conversions, inheritance, volume scale, missile minima, known-zero cargo, no duplicated aliases, equipment fit/storage and save/reload. Compare three concrete loadouts for each hull: standard, current equipment transferred, and maximum permitted. Researching a weapon type without its firing/damage/heat readers does not close that field.

## Elite Dangerous outfitting inputs and common project refits

D23 is the [EDCD Coriolis data repository](https://github.com/EDCD/coriolis-data/tree/0db9234b5b9ce8c939ea84133d7ce336eea88e27), pinned on13 October2026. The [normalized dataset](data/elite-dangerous-outfitting.json) contains47 hull records and970 module records. Hull fields include base speed/boost, shield-strength input, armour, mass, turning, heat, slot sizes/restrictions and default loadouts. Module fields retain laser damage/range/cadence/heat/power, missile rack clip/reserve ammunition, shield/FSD/thruster and other numerical parameters. This is community outfitting data, not recovered Frontier server code.

Derived standard cargo sums the racks actually installed in each default loadout. The separate all-unrestricted-slots ceiling installs racks in every unrestricted optional slot and removes shield/other optional gear; it must not be displayed as cargo available with the current equipment. Restricted slots are excluded. Native ED missile capacity depends on the selected rack and its clip/reserves, not a single permanent hull value. Base shield/speed values are calculation inputs, not complete fitted/engineered ship performance.

The common project profiles retain canonical IDs and use Oolite-like flight/equipment. Existing known player holds take precedence, including the Oolite Asp's zero. ED-only entries borrow their default rack capacity, while speed/armour/shields use explicit Cobra-relative conversions. Missing flight properties use a labelled Cobra reference. A ship without inspected geometry uses a named surrogate and explicit scale; exact previews remain provisional. The common 350-unit Cobra reference, mappings and equipment costs are in [estimate policy](project-estimates.md). Original edition data and mission NPCs remain separate.

All161 current profiles contain cargo, expansion, speed, acceleration, roll/pitch/yaw, hull energy/generation, fore/aft shields/recharge, laser facing/type, missile capacity/initial stock, range/fuel/spool, docking computer, drive and equipment capacity. This is enough to implement numerical common-flight refits. Accurate rendering, collision/docking envelopes for external models and balancing require further checks. Native ED missile/laser statistics remain in D23; the common project uses the O08 weapon definitions instead of silently mixing those engines.

## Oolite inheritance correction

Pinned O08 OOShipRegistry.mergeShip removes like_ship after merging; display_name and is_template are not inherited unless the child specifies them. When alternate spellings conflict, the child determines scan class, escort role/ship, carrier and shipyard precedence. The194 core,2,184 expanded and93 selected combat dictionary records now apply these semantics. Own source fields/hashes are preserved. This changes inherited metadata, not numerical combat parameters, and avoids incorrectly classifying a child of rock-hermit as an unspawnable template. Source aliases and runtime defaults remain distinct.

[Crew and passenger capacity](crew-and-passenger-specifications.md) now records every current catalogue row in the [per-ship list](ship-crew-list.md): 173 edition facts, selected crew requirements/labelled size-equipment-cargo estimates, reserved operating quarters, real 5-tonne/1-equipment-unit passenger berths and atomic mission/shipyard fit checks. [SH165 Vector](vector-arn-mission-specifications.md) adds one deduplicated hull with NPC/Arn/SE refits and measured source envelope; the research catalogue now has 170 rows and 161 filled common player refits. Further expansion hull identity work remains open.

[SH166 Arafura and SH167 GC inspection craft](rescue-inspector-ship-specifications.md) extend the common player dataset to158 refits across167 canonical records. The source player Arafura uses125-tonne hold, six pylons/three initial missiles and source shipyard mask3; the inspector is an explicit NPC-to-player conversion with20-tonne hold and the required one-missile baseline. Their native NPC configurations remain distinct.

[SH168 Minnow, SH169 Ray Mk I/Sunray and SH170 Military Stingray](commies-selected-ship-specifications.md) extend the current research catalogue to170 identities/161 common refits, with exact selected2.20 envelopes, source-player/NPC differences, one source-standard fitted Sunray berth and verified twin-emitter semantics. Current authoritative native ship TOMLs preserve their maintained simulation/economic values; these common-unit source inputs are not automatic runtime overrides. The [runtime handoff contract](runtime-pack-handoff-contract.md) specifies actual calibration, capabilities, media and save boundaries. Existing schema does not yet establish crew/cabin/storage/multiple-emitter gameplay support.

## Transporter cargo correction14October2026

[SH128 correction evidence](data/transporter-refit-correction.json) replaces the common player refit's volume-based zero cargo estimate with12tonnes, explicitly borrowed from pinned O08 oolite_template_transporter max_cargo12. The prior zero was an estimate, not a known historical player hold; this does not alter native NPC statistics or claim the Transporter was originally a flyable Oolite ship. Operating crew remains3 in intrinsic quarters, equipment budget8, initial charter berths0, expansion0 and the owner's initial player missile1. With actual fitted5t/1unit cabins, an otherwise empty refit can accommodate2passengers and2tonnes of freight; three cabins do not fit. No cabin is installed for free. Eight accounting cases and the existing170row/161refit/50FFEbinding/25fitcase crew checks pass; source edition facts remain173. Persistent unique equipment/storage and protected mission-custody checks still control actual transfers and acceptance. Native implementation is pending.
