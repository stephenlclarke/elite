# Elite mission replication specification

**Active scope excludes Frontier/First Encounters, all Elite Dangerous Operations and other ground/on-foot missions. The [scope](implementation-scope.md) takes precedence.**

The definitive scope applies to each mission, including its playable text, optional branches and dependencies. Retained missions with planetside elements now use explicit station-handoff replacements; original ground gameplay remains reference-only. Keep separately specified eligible space missions within mixed campaigns, including the explicit P01 space-station supply adaptation with a station handoff. All research permissions remain in force; neither a source graph nor a catalogue ID alone authorizes activation.

This specification describes mission behaviour for the identities in [missions](missions.md). Version profiles are in [versions](versions.md); source IDs resolve in [sources](sources.md). Historical facts are labelled by profile. The shared runtime and acceptance scenarios are proposed implementation rules for this project. Unspecified historical numbers are not supplied as invented defaults.

## Mission runtime contract

Represent a mission definition separately from its generated instance and the player's progress. A definition owns the canonical ID and profile; an instance owns selected systems, targets, deadlines, random seed and reward parameters; progress owns completed stages, cargo, target outcomes and paid rewards.

Persist at least: mission ID; profile/build; state; acceptance time; timer domain; chosen destinations; target identity and spawn state; mission-specific items; unique objective completions; refusal/failure flags; follow-up eligibility; reward-paid flag; altered world entities; current generator seed. Do not regenerate an accepted mission when reopening a menu or loading a save.

Use the following event vocabulary as project design, not as a claim that every original game used this architecture:

- `Docked(stationID, systemID)` and `Launched`.
- `SystemEntered(galaxyID, systemID)` and `JumpStarted`.
- `TimeAdvanced(simulationTime)` and `TimerExpired`.
- `EntityDestroyed(entityID, creditedActor, cause)` and `TargetEscaped`.
- `CargoScooped(itemID)`, `CargoTransferred`, `CargoJettisoned` and `CargoLost`.
- `ScanCompleted(objectID, equipmentID)` and `PhotoTaken(targetID, distance)`.
- `PassengerBoarded`, `PassengerDelivered` and `PassengerLost`.
- `InstallationDisabled(objectID)` and `MissionItemUsed(itemID)` for ship-accessible objectives.

Process transitions deterministically. On completion, update the state, pay the reward and set the paid flag atomically. Unrelated kills, equivalent market cargo, repeated scans and menu refreshes must not satisfy unique-object objectives. Choose whether timers run during time acceleration, docking or offline time per profile. Do not turn a docking-count penalty into a real-time deadline.

## Required specification fields

Each implementation must resolve: prerequisites; offer location and event; acceptance/refusal; objective order; locations and navigation hints; relevant ships/items/equipment; spawn conditions and AI; timer and units; success predicate; failure/abandonment; reward; legal/reputation changes; persistence; repeatability; historical bugs. A missing required value prevents a fidelity claim even if the broad mission is playable.

## C01 Constrictor Hunt

**BBC-derived mission outline [S04]:** Offer on docking in galaxy 1 or 2 at 256 combat points, once only. Route clues lead from Xeer/Reesdice to Arexe, then in galaxy 2 through Errius, Inbibe, Ausar and Usleri to Orarra. Other systems point toward Errius. The target has ECM and military-laser-resistant shielding against weaker lasers. Destruction sets a flag; the assignment pays 5,000 credits and 256 bonus combat points. Bonus timing is port-specific: C64 adds the 256 points on target removal and cash on debrief, with the second point increment disabled in DEBRIEF [S34]. The saved TP low bits progress 00 -> 01 -> 11 -> 10. No explicit deadline is established.

**Version differences:** The BBC disc energy bomb can destroy the Constrictor; later official 6502 profiles cannot [S01]. Oolite requires score >255 and a main station, spawns the target at galaxy index 1/system 193, and clears the player's bounty at debrief [O01]. The MSX disk source uses a 64-arrival assignment scheduler, procedural clue trail, quarter laser damage and a 10,000-credit debrief, plus a separate 400-credit bounty; see the [Z80 profiles](z80-port-profiles.md) [S41].

**Additional source profiles:** ST uses a generated furthest-system route and five clue hops; GBA has easy-mode thresholds; Oric uses a G4/G5 trail and different rewards. See [classic ports](classic-port-profiles.md) and [Oric](oric-mission-specifications.md).

**Project state machine:** unavailable -> briefed -> hunting -> target destroyed -> debriefed. Clue visits are navigational hints, not mandatory checklist stages unless the selected original script proves otherwise. Keep one mission target identity; preserve the destroyed state through save/reload before docking.

**Acceptance scenarios:** 255 points cannot trigger; 256 can in the eligible galaxy. A lookalike ship does not complete the mission. Killing the target does not pay twice. Wrong-system docking before the kill does nothing. Verify bomb immunity under each profile. Specify whether NPC destruction counts from the original target script before implementing that edge case.

## C02 Thargoid Plans

**6502 profile, sourced facts [S05]:** Requires C01 finished, galaxy 3 and TALLY high byte >=5, equivalent to at least 1,280 combat points. Dock to receive the Ceerdi instruction; dock at Ceerdi (215,84) to collect plans; dock at Birera (63,72) to deliver. TP low nibble follows 0010 -> 0110 -> 1010 -> 1110. Carrying plans changes enemy spawning: a Thargoid/Thargon encounter is selected about 22% of relevant spawn checks, not every frame. Reward is a naval energy unit and 256 combat points. No stated deadline.

**Oolite difference [O02]:** Requires score >1280, completed C01 and a main station outside system 83. Collection is system 83; delivery system 36. Initial population adds three Thargoids, with up to two further ambushes during early repopulation. Replace a normal or damaged energy unit with the naval unit and charge fitting time.

**Additional source profiles:** ST delivers documents directly to a generated destination; Oric has its own Rianxe debrief and pursuit hook; GBA has separate easy-mode thresholds and coordinate guards. See [classic ports](classic-port-profiles.md) and [Oric](oric-mission-specifications.md).

**Project state machine:** unavailable -> summoned -> carrying -> delivered. A source-station visit before summons must not issue plans accidentally. Activate pursuit only while carrying. On delivery, remove mission pursuit hooks and award equipment once. Plans are mission data unless the chosen profile defines physical cargo; do not assume they occupy one tonne.

**Acceptance scenarios:** completed C01 plus 1,279 points fails the BBC gate; 1,280 passes BBC but not the inspected Oolite >1280 gate. Birera before collection cannot complete. Save/reload while carrying retains pursuit. Repeated Birera docking cannot award duplicate equipment or points.

## C03 Trumble infestation

**C64/NES profile [S06]:** A merchant offer costs 5,000 credits, seeds one creature, and is offered once. Creatures multiply during jumps and flight, consume food, and in C64 also consume narcotics. C64 displays canopy sprites; NES calls them Little Squeakys and omits canopy sprites. Sun heating kills them; an escape capsule does not cure the infestation. The threshold disagreement is resolved for the inspected source: C64 tests a single cash byte, so eligibility wraps; NES tests the high cash bytes and needs >=6,553.6 credits. The complete purchase, register-level breeding, cargo and heat rules are in [classic port profiles](classic-port-profiles.md), S34/S35.

**Oolite offer profile [O05]:** At a main station, eligible offers have 20% probability and need >6,553.5 credits; purchase costs 30 credits. Refusal can reset at 2% per jump. Nova progress suppresses offers. This offer script does not define breeding or heat constants.

**Project states:** unoffered -> offered -> refused or infested -> cured. Persist population, consumed goods and offer history. The original no-refund outcome is not a cash reward. Track reproductive tick cadence separately from rendering frame rate.

**Acceptance scenarios:** decline never deducts money; accept deducts exactly once. Escaping does not reset population for C64/NES. High heat reduces population while ordinary temperatures do not. A save with one creature remains infested. Use the supplement for population overflow, heat 240, RNG carry, cargo clearing and escape survivors; original loop cadence and visuals still require the selected engine profile.

## C04 Supernova rescue

**Oolite profile [O03]:** Galaxy 4, more than three counted entries, a working galactic drive and ordinary space trigger the emergency. A fuel leak and two-hour nova timer encourage docking at the main station. Accepting loads refugees, launches the player, destroys stations and reduces the timer to 30 seconds; refusal gives nine seconds. Successful escape then main-station debrief in galaxy 4 or 5 clears special cargo and grants 100 units of gems. Escape-pod use and refusal have separate outcomes; refusal harms contract/passenger reputation. The devastated system persists.

**ST source:** 64-jump scheduler, cargo cleared even on refusal, raw gemstone overwrite and sun progression are specified in [classic ports](classic-port-profiles.md).

**Other ports:** The identified MSX disk source clears cargo even on refusal and replaces the gem quantity with 50 grams at successful debrief; the earlier 50 kg report is superseded [S41]. Escape-drive and scene parity still require fixtures. The [Z80 profiles](z80-port-profiles.md) also establish the Spectrum compatibility release's 100-gram replacement and selected 256-point awards [S42]. PC Plus rescues refugees to another system and reports cash [S09]. Do not universalise Oolite's jump count, countdowns or reward.

**Project states:** dormant -> emergency -> accepted/refused/ignored -> escaped/lost passengers -> debriefed. Persist destruction separately from mission progress. Record whether local or galactic jumping is valid for each profile. Preserve capacity and cargo replacement behaviour; do not assume ordinary passenger cabins are required in classic Elite.

**Acceptance scenarios:** saving cannot reset the nova timer. Leaving without docking follows the ignored path. Accepting cannot leave stations available as an escape-pod loophole. Successful hand-in grants gems once. Test refused, ignored and escape-pod outcomes separately.

## C05 Cloaking device

**MSX disk profile [S41]:** A scheduled Cougar attack awards a separate 500-credit bounty; destroy it and scoop its special dropped container for the cloak. The scoop path requires fitted scoops and the correct approach, bypassing ordinary full-hold checks. See [Z80 profiles](z80-port-profiles.md). **PC Plus [S09]:** A nearby-system encounter uses three cloaked Asps with supporting Cougar/Constrictor craft; recover a device and return to the issuer. **Oolite [O04]:** In galaxy 5, counter >6 can populate a cloaked Asp group at the arrival point while the encounter is unresolved. Equipment and pod scripts determine acquisition; they must be checked alongside the mission script.

**ST source [S36]:** the Cougar drops one negative-type equipment canister when allocation succeeds; a fuel scoop and the correct approach fit the cloak, even with a full ordinary hold. Removing the Cougar ends the mission independently of recovery. Exact header statistics, frame-counter cloaking and acquisition branches are in [classic ports](classic-port-profiles.md).

**Project states:** eligible -> encounter spawned -> carrier destroyed -> device recovered -> fitted/debriefed. A destruction bounty is separate from acquiring equipment. Keep the drop unique and persist whether it was recovered or lost. BBC-MASTER's ordinary cloaked Cougar is a ship behaviour, not proof of this mission.

**Acceptance scenarios:** kill without scoop does not award a scoop-based cloak. Unrelated cargo does nothing. A cloaked target's visual/scanner treatment follows its profile. Exact respawn-after-lost-pod and equipment energy consumption remain unresolved for several ports.

## C06 Thargoid occupied station

**Reported behaviour [S07, S09]:** Assign an invaded system, increase Thargoid opposition, make the occupied station destructible, then require docking elsewhere or return to the issuer for an ECM jammer/anti-ECM reward. PC Plus also reports an Archangel status and possibly adverse legal effects; those require binary verification.

**ST source:** next-destination occupation, 200-frame reinforcement counter, Dodecahedron station and ECM-jammer debrief are in [classic ports](classic-port-profiles.md).

**Project states:** assigned -> invaded system -> station destroyed -> reported. The mission changes one station instance's invulnerability; ordinary stations remain protected. Remove hostile occupation only for the selected target. Keep reward, legal changes, galaxy selection, station hull, spawn rate and exact debrief location in per-port configuration. Those numerical values remain unresolved.

**Acceptance scenarios:** destroying a different station does not complete; target destruction without debrief does not pay; ordinary stations do not become destructible globally; save/reload preserves the target's loss.

## C07 Stolen Police Ship

**PC Plus [S09]:** A named-system search-and-destroy assignment with cash payment. Target type, cash, counters and respawn rules require a binary/playthrough fixture.

**Project sequence:** offer -> accept -> enter target system -> identify unique stolen craft -> destroy -> debrief. Separate this from C01: a similar hunt is not evidence of the Constrictor script. Acceptance scenarios must include innocent police craft, target escape, wrong location, issuer return and repeated debrief.

## C08 Asteroid Bombardment

**PC Plus [S09]:** A named system has extra asteroids, including near its station; sufficient destruction leads to cash on docking. The exact quota, placement, clock, laser requirements and payout are unresolved.

**GBA-TNK source [S37]:** repeatable 30-asteroid assignment, 6,000-credit reward, off-target asteroid credit, exact spawn rules and initial-destination defect are in [classic ports](classic-port-profiles.md). These facts do not establish PC-PLUS parity.

**Project sequence:** assigned -> bombardment active -> quota reached -> docked/debriefed. Count only mission asteroids or the exact population category verified by the source build. Do not count unrelated mining indefinitely. Verify whether station survival or a timer is actually a historical failure condition before adding it.

## C09 Genesis Capsule

**ARC profile [S08]:** Galaxy 1; 550 kills and 1,200 credits reported. The previous numbers were reversed. Collect a GalFam ecology capsule, approach the assigned starving world and jettison at low altitude facing it. Reward: 500 credits and changed planet description.

**Project states:** offered -> capsule collected -> valid release -> planet improved -> paid. Bind capsule and planet identities. S40 reports Razaar -> Ordima -> Xeaan, a 150-credit pickup deduction and failure on wrong planet/direction/height or capsule destruction; the capsule is jettisoned last. Required unresolved values: binary index selectors, altitude/facing tolerances and precise boundaries. Test wrong planet, too-high release, valid release and permanent post-save planet change.

## C10 Kill Zartid III

**ARC profile [S08]:** 1,450 kills and 4,000 credits reported; any galaxy. Hunt a traitor in a blue wing-shaped vessel with Mamba escorts; delay can bring reinforcements. Reward: yaw boosters.

**Project sequence:** briefed -> trail -> target encounter -> target destroyed -> reward. S40 reports system index 116, five Mamba escorts and failure after more than 15 dockings. Unresolved: exact spawn/wave trigger, traitor hull identity, statistics and debrief. Do not name the blue craft as a particular model without evidence. Tests: escorts alone do not finish; target persists correctly; reinforcements do not duplicate on reload; boosters awarded once.

## C11 Kill Zurid Pino

**ARC profile [S08]:** At 2,600 kills, a revenge encounter uses a stolen Cobra, invisible to scanner, carrying eight missiles. Reward: missile autolock.

**Project sequence:** eligible -> ambush -> target destroyed -> reward. Preserve target identity, cloaking and missile inventory. S40 reports a follow-up at 2,650 kills with system index modulo 5 equal to 1, then an encounter under government type <3. Unresolved: exact score comparisons, cloak rendering, weapon values and reward event. Tests: finite eight-missile supply; scanner concealment; one equipment reward; no duplicate mission target.

## C12 Medicine Run

**ARC profile [S08]:** 4,600 kills and a reported planet-number modulo-three gate. Collect cure ingredients from multiple stops and use a mixing centre. Some ingredients react to heat or loss of shields. Reward: 2,000 credits and inoculation.

**Project sequence:** commissioned -> collecting -> mixed -> delivered. Track each ingredient and its reaction conditions separately. S40 reports systems 170-174, Paredon reacting with other Zeenogenic compounds after shield loss, and escape-pod retention of compounds. Named stops are galaxy-dependent; exact ingredient-to-index mapping, quantities and heat/damage equations remain unresolved; this is not sufficient for numerical parity. Tests must cover safe storage, each dangerous combination, depositing ingredients and permanent cure status.

## Oric campaign and tutorials

The [Oric specification](oric-mission-specifications.md) supplies R01-R10, T01-T04 and the Oric C01/C02 profiles. It includes the branching campaign, every mission file, cargo quantities, destination indices, encounter positions, counters, completion callbacks and failure byte. Keep its source rewards and tutorial retries separate from BBC and ST profiles.

## Generated objective implementation recipes

These recipes support the retained ship-based G families in the active catalogue. Removed IDs are not reused; the [scope](implementation-scope.md) excludes Frontier and ground/on-foot variants. They describe the retained objective structures; reproducing a particular game's generator additionally requires its offer distribution, arithmetic, reputation gates and original content data.

| IDs | Required parameters | Sequence and success predicate | Failure and acceptance cases |
| --- | --- | --- | --- |
| G02 | issuer, payload ID, origin, destination, deadline | Accept unique data/package; deliver to correct contact. | Expiry, abandonment and specified payload loss; wrong station and unrelated goods cannot complete. |
| G03 | supplied/procured flag, commodity, quantity, destination, provenance rule | Load supplied cargo or acquire commodity; deliver required amount. | Supply rules differ from ordinary market substitution; persist partial deliveries and recompute remaining quantity safely. |
| G04 | destination coordinates, initial reward, fee, legal increment | Elite-A: accept/pay; on intermediate docking halve stored reward; destination docking pays remaining reward/10 credits and clears it. | Reward reaching zero ends the job. Hyperspace alone does not halve it. See S10 and the notes below. |
| G05 | passenger IDs, cabins, pickup, destination, deadline, risk | Board only with capacity; transport named passengers; disembark. | Passenger loss/expiry and contract-specific hostility; test ship exchange and cabin removal. |
| G06 | VIP, cabin class, ordered beacons, destination, demands | Board; satisfy scan itinerary; return or deliver. | Track scans in order where required, satisfaction and optional demands separately. |
| G07 | unique target, route/schedule, kill-credit rule, issuer | Locate; destroy allowed ship target; report. | Escaped target, wrong victim, civilian penalties; story-specific pre-jump requirements override generic pursuit. |
| G08 | faction/target class, quota, valid region, credit sharing | Count qualifying kills until quota; report. | Unrelated kills and duplicate kill events do not count; wing sharing is explicit. |
| G12 | victim/hostages, containers, legal basis, quantity | Find vessel; release/scoop correct cargo; hand in. | Killing hostages, generic lookalike cargo, expiry and legal consequences. |
| G13 | wreck/site ID, recoverable item IDs, quantity | Locate mission signal/site; recover; deliver. | Unique provenance, space retrieval and loss; unrelated black boxes never substitute by name alone. |
| G14 | ship-scannable data point, access rights, scan/download duration | Locate and interact; hold required access; capture data. | Alarm/timeout only if specified; wrong data point and interrupted download do not finish. |
| G16 | ship-accessible installation/process, sabotage method, ship interaction | Reach correct device; destroy or insert sabotage payload. | Similar nearby devices are not sufficient; alarm and collateral rules remain constraints. |
| G20 | commodity, extraction requirement, amount, delivery | Mine/refine permitted resource; deliver. | Buying may not count if provenance is required; partial deliveries use exact mass units. |
| G21 | currency or commodity, amount, recipient | Transfer atomically; apply reputation/influence. | Insufficient funds/items makes no partial mutation unless allowed; no invented cash reward. |
| G22 | evacuees/pods, capacity, danger, destination, deadline | Embark/scoop; survive; deliver survivors. | Distinguish cabin evacuees from cargo pods; casualty count, station hazards and rewards must be configured. |
| G24 | alien vessel class, region, quota, credit rules | Destroy only designated alien targets; report if required. | Human kills never count; AX encounter variants, event availability and kill sharing are separate profile fields. |

The [fourteen filled project variants](generated-space-project-specifications.md) now supply bounded counts, timers, rewards, encounters and deterministic generation. Their estimates remain separate from the original game/server generators.

### Elite-A generator fidelity

S10 establishes that the menu remains stable during a station visit and that delivery state stores reward plus destination coordinates. It is regenerated after relevant market/ship state changes. Acceptance costs a fee and may add to legal status; intermediate docking right-shifts a 16-bit reward. A generic continuous clock penalty is incorrect.

For exact offers, use the pinned original `cour_buy`, `cour_count`, `cour_dock` and commander-save arithmetic linked in S10. The [Elite-A courier specification](elite-a-courier-specifications.md) now transcribes wrapping carry/borrow operations, seed selection, distance rounding, fee/reward construction and legal effects, with1,024 menu comparisons and exhaustive16-bit square-root checks. Retail UI/original executable parity remains separate. Test an all-sun-scooping journey against one with intermediate docking; merely flying farther or waiting must not halve the reward.

## Oolite expansion campaigns

P01-P48 are optional mission pack discovery IDs catalogued in [missions](missions.md). A pack can contain many missions, custom systems, ships and scripts. Base-game C01-C05 state machines do not supply their plots. To reproduce a pack, freeze its version and create a stage graph with the required fields above for each sub-mission; identify every script timer, random branch, target, equipment dependency and persistent mission variable.

The [expansion supplement](oolite-expansion-specifications.md) specifies P03/P04/P09/P18/P23/P25/P26/P27/P33/P35/P36/P37/P38/P40/P41/P42, including branches, rewards, deadlines, encounters and source quirks. P40 ends at a published continuation notice; P26 distinguishes historical 2.5.3 from the source-blocked 3.0 finale. Its [package manifest](data/oolite-pack-sources.json) freezes40 downloaded package revisions and file hashes. Combat resources and selected Oolite engine semantics are recorded separately. Other pack entries remain discovery records, and even an R1 core graph still requires its engine/resources for exact parity. Preserve known dependencies from O06, including native-mission prerequisites and deprecated compatibility. In particular, Asteroid Storm is a distinct campaign from C08 despite a similar theme. Do not invent campaign endings from names such as Cataclysm or Iron Raven.

P01's Black Mesa on-foot adventure is removed from the active project profile. Its source graph is archived; a docked missile-supply transaction bridges the retained flight finale as described in [scope](implementation-scope.md). P48 remains a ship-based campaign.

Additional recovered profiles: [Aquatics](aquatics-mission-specifications.md), [Black Sunspot](black-sunspot-mission-specifications.md), [Escort Contracts](escort-mission-specifications.md), [Illegal Goods Tweak](illegal-goods-mission-specifications.md), [Lave Academy](academy-mission-specifications.md) and [Shrews' Rights](shrews-mission-specifications.md). Apply the [station-handoff contract](station-handoff-specifications.md) to each documented original ground stage.

## Additional recovered space campaigns

[Galactic Almanac](almanac-mission-specifications.md) establishes the hidden courier sequence, exact station route and payout. [Feudal States](feudal-mission-specifications.md) establishes six court families, challenge/tournament rules and orbital court mappings. [Resistance Commander](resistance-mission-specifications.md) establishes six squadron combat families and morale endings; the separate unfinished ENVOY code is reference-only. Use the [coordinate contract](oolite-coordinate-contract.md) for legacy mission positions.

[Galactic Navy/Admiral Kurtz](navy-mission-specifications.md) establishes the recovered Switeck MOD reserve profiles, personal/battle completion states, sortie bonuses and three Kurtz endings. The original shuttle planetary landing becomes an orbital station escape handoff. Modified and original Navy revisions remain distinct.

[P43 To Catch a Thargoid](to-catch-thargoid-mission-specifications.md) now has a dedicated source/profile analysis and31 selected callback checks. [Mechanics appendix](data/tcat-mechanics.json) records32 AI state tables and18 numeric equipment definitions. Bomb placement becomes an automated central-station handoff, with verified10second escape countdown; source narrative30seconds and ship-switch cancellation are not silently carried into the repaired player profile.

[P06 Cataclysm](cataclysm-mission-specifications.md) is now analysed, with30 selected callbacks and a [mechanics appendix](data/cataclysm-mechanics.json) containing14 AIs,100 directed interstellar bindings and source equipment/yard values. The source5120gate,17tickscan, A/Brescue paths, named stations and repeat-offer defects are distinguished from necessary project repairs. [Newly recovered P46 distribution](data/legacy-source-recovery.json) remains an analysis gap; P22 is now analysed in [Localhero](localhero-mission-specifications.md) and P16 in [Most Wanted](most-wanted-mission-specifications.md).

Additional recovered profiles: [P05 Blackjack](blackjack-mission-specifications.md), [P28 Oo-Haul](oohaul-mission-specifications.md), [P32 RunnerG5](runner-g5-specifications.md), [P47 Victim11](victim11-mission-specifications.md), with25 selected source callbacks and [466 legacy resource definitions](data/legacy-expansion-resources.json). P24 is corrected to the author-described [Grand Tour activity](grand-tour-specifications.md), with five tour/challenge endpoint bindings independently matched between recovered C and project Swift. New numeric project choices and repaired callbacks remain labelled; original narrative/graphics are not copied.

[P21 LinkG7](linkg7-mission-specifications.md) is now recovered and analysed. Public folder inventory identifies file631078585, LinkG7v0.1.zip,6768bytes; all eight textual member hashes are in [legacy recovery](data/legacy-source-recovery.json). [16 source callbacks](data/linkg7-source-fixtures.json) and [eight independently matched route endpoints](data/linkg7-route-bindings.json) establish the trial, while prototype installation, missing reoffer, wrong-galaxy progression, outbound midpoint range and unbounded retry defects have explicit project repairs.

[P44 Trident Down](trident-down-specifications.md) now has the four-way investigation/political campaign, nine advertised story endings plus initial rejection, station handoffs and explicit missing failure-path repairs. [40 selected callbacks](data/trident-source-fixtures.json), [complete explicit stage/effect graph](data/trident-source-graph.json), [resolved119 definitions/27 AIs/22 route bindings](data/trident-mechanics.json) and [three recovered dependency revisions](data/trident-dependency-sources.json) retain inspectable provenance. All12 previous P44 parent gaps are resolved; source tier/equipment values remain distinct from eventual player refits.

[P46 Benus escort and Arn prototype](vector-arn-mission-specifications.md) are individually ready with 35 selected callback checks, explicit orbital boarding/medical/sabotage replacements, finite reachable route generation, unique reward/storage and gallery contracts. This bounded packet does not close the other Vector salvage/inspection/Areidis/specialist families.

[P46 Richmans World and flight inspection](vector-salvage-inspection-specifications.md) are now individually ready and delivered: six settlement choices, exact quote/risk/strength rules, scanner approach/compliance/fines, explicit once-only payment and safe custody repairs, 78 selected source callbacks and 20 CCL callbacks. [Shared Vector mechanics](data/vector-services-mechanics.json) pin 87 definitions, 21 AIs, 24 base envelopes and 36 station flag rows; aliases/components are not additional hulls. Original NPC energy inputs require the explicitly borrowed O08 booster/enhancer assembly; native implementation remains separate. Areidis/Specialist station closure is still pending.

[P46 Areidis terminals and Specialist trade](vector-station-specifications.md) complete the recovered Vector objective inventory: 24 scripts accounted for across six retained bounded mission/event families, 17 selected station checks, five identical decrypted messages with no invented continuation, seven independently matched endpoints, source gram-unit market rules and explicit orbital/animation/custody/reward repairs. Missing scanner unlocks, empty/future phone/actor handlers and original walking/cubes remain reference-only. All six profiles have been delivered incrementally with gallery requirements; original-engine parity and native implementation remain separate.

## P30 derelict escort variants

[Rescue Stations escort specification](rescue-escort-mission-specifications.md) closes base1 and variants1a/1b individually. It supplies offer/route/board/reputation gates, source NPC pools/loadouts/AIs, eight repair phases, all three hazard schedules, original-station return, payout/failure, optional formation equipment and save/gallery contracts. The selected1b gate and anomaly timing repairs are explicitly labelled. The full P30 package remains partly analysed.

## P30 station courier variants

[Local documents2 and sensitive evidence2a](rescue-courier-mission-specifications.md) supply complete source gates, source30/150credit outcomes, two-hour strict deadline, seven hunter configurations and source route/catchup behaviour, with necessary acceptance/custody/persistence repairs and separate gallery entries. These are orbital main-station jobs, not passenger or physical-crate assignments. Solar laboratory2b remains separate.

The owner now requests [RRS contract-board support](rrs-contract-board-specifications.md), including headquarters through an explicit project capability. Native HQ no-board evidence is preserved, accepted contracts retain the original station identity, and only individually completed/implemented/safe profiles become live offers. No raw package or research-open solar lab is enabled by this UI extension. The board has separate isolated gallery and save/fit acceptance requirements.

## P30 solar laboratory2b

[Portable solar lab specification](rescue-solar-mission-specifications.md) supplies complete offer, station/HQ checkout/deposit, heating/alignment/processing/recovery, original-station on-time/late endings, unique equipment/return-only custody and saved gallery contracts. Recovered unconditional reaction completion and deposit-without-payment defects are explicitly repaired; the selected1/60-second thermal integration and one-tonne intake clearance are labelled project choices. Source constants,22 callbacks,15 repair/accounting cases and45 C/Python comparisons support the profile.

## P30 black-box recovery3/3a

[Standard and conspiracy recovery](rescue-blackbox-mission-specifications.md) supplies source route-based time/reward, one-tonne scoop custody, precise field/ambush/return hunter mechanics, source-deadline versus repaired acceptance clock, corrected variant guards, saved source-path tie ordering and original-station/HQ return/gallery.7172staticroutes and311alternate-time ties are retained;44sourcecallbacks and8narrowrepaircases pass. Actual navigation must support the selected O08 integer-y graph, not an incompatible float-half-y substitute.

## P30 pilot transport4

[Personnel recovery specification](rescue-personnel-mission-specifications.md) completes base4: one actual fitted compatible berth, source rep/legal/distance/count/route/time/reward parameters, automatic target main-station boarding and exact original-station/HQ handoff. Both source on-time and late code paths pay the full quote; only timely return gives+10rep/success, while late is failed/no rep change. Sixty source cases,4563 filtered source-route candidates/194 time ties and explicit owner capacity/life-support/clock/custody/identity repairs support save/gallery/native acceptance requirements. Variants4a/4b have separate completed profiles below.

## P30 captured-pilot rescue4a

[Slaver recovery specification](rescue-slaver-mission-specifications.md) completes the base4 replacement: source eligibility and near-system routing, one fitted pilot berth plus sealed-pod hold, finite five-captive Python/defender/base combat, medical identity/50n rewards, partial5n-30 reputation and both full-pay home outcomes.74 source cases,16 selected patch/mathematical checks,2448 native/2446 positive-time project routes and18 model vertex/hash checks support explicit repairs, saved custody and isolated gallery. Optional external ship wrappers and unimplemented commando hints do not create new objectives or hulls.

## P30 Astromine escape4b

[Astromine escape specification](rescue-astromine-mission-specifications.md) closes the personnel family: agent fitted berth and roster station-service wait, exact mine30/65second queue/guard events, actual fragile mining-craft wormhole transit/home custody, source1250/+20 reward/redock-15/player-kill-110 endings and fading100day diplomatic record.67 source cases,17 selected actual-source patches,17 C/Python wormhole comparisons and16 independent model checks support the labelled identity/time/AI/ban/formation/save/gallery requirements. Each variant replaces at most one eligible base slot on a saved board; no on-foot stage or free player craft is added.

## P30 emergency freighter escort5

[Emergency escort specification](rescue-emergency-mission-specifications.md) completes base5: source250+50K reward, actual local full-speed freighter delivery, four bound hulls, eleven core pirate choices, native mixed escorts, two/three RRS defenders and source-5/-25 failure outcomes.63 selected callbacks,20 narrow actual-source patches,62 selected hashes and17 independent model envelopes support exact-home/terminal/bonus/refuel/group-index/high-score-count repairs and isolated gallery/save requirements. Returning-Arafura variant5a remains separate and open.

## P30 returning Arafura escort5a

[Returning-Arafura specification](rescue-returning-mission-specifications.md) establishes150-second rendezvous, one5..15-second delayed opposition event,60/30/8/2% fleet types,50/25/25% targets,350+50K deferred payment and exact original-home delivery.57 source cases,51 selected patch/adapter checks,36 C/Python expression cases and18 independent meshes support explicit clock/timer/identity/helper/fuel/crew-escape/terminal/gallery requirements. A real crew capsule preserves living people while an abandoned protected hull closes ordinary failure under a labelled repair; there is no free player passenger manifest or new hull identity.

## P30 recovered materials transfer6

[Materials specification](rescue-materials-mission-specifications.md) completes base6 with source route/quote/deadline/late outcomes, finite seven-hull hunter budget and native AI/geometry/fuel.51 source callbacks,29 selected patches,23 C/Python numerical cases,65,536 independent count-grid comparisons and2738 routes/174 alternate-time ties support explicit one-tonne custody/fit, count/entry/identity/actual-arrival/receipt/save/gallery repairs. Medical6a remains separate and open.

## P30 medical supplies delivery6a

[Medical specification](rescue-medical-mission-specifications.md) completes the fifteenth actual P30 scenario/variant: two-leg high-tech pickup/orbital mining-hospital delivery, source full-pay/+15 and late/missed/ordinary failure graph, finite per-entry native pirate bursts, physical fixed full-hold shipment and existing-site overlay.92 source cases,72 selected source-patch/custody cases,105 C/Python cases,4074 independent route queries and2048 verified mine centres bind explicit route/clock/identity/cargo/shipyard/receipt/news/save/gallery repairs.3657 own-target triples yield3649 shared-base-slot triples;13 existing canonical ship IDs are reused without a new hull or alien. Native implementation remains required.
