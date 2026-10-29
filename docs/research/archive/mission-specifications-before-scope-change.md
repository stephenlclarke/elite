# Archived: mission-specifications.md before mission scope change

**Excluded reference snapshot. Do not implement removed mission content from this document. The active [scope](../implementation-scope.md) takes precedence.**

## Elite mission replication specification

This specification describes mission behaviour for the identities in [missions](../missions.md). Version profiles are in [versions](../versions.md); source IDs resolve in [sources](../sources.md). Historical facts are labelled by profile. The shared runtime and acceptance scenarios are proposed implementation rules for this project. Unspecified historical numbers are not supplied as invented defaults.

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
- `PowerChanged`, `FireExtinguished`, `AlarmRaised` and `PersonKilled`.

Process transitions deterministically. On completion, update the state, pay the reward and set the paid flag atomically. Unrelated kills, equivalent market cargo, repeated scans and menu refreshes must not satisfy unique-object objectives. Choose whether timers run during time acceleration, docking or offline time per profile. Do not turn a docking-count penalty into a real-time deadline.

## Required specification fields

Each implementation must resolve: prerequisites; offer location and event; acceptance/refusal; objective order; locations and navigation hints; relevant ships/items/equipment; spawn conditions and AI; timer and units; success predicate; failure/abandonment; reward; legal/reputation changes; persistence; repeatability; historical bugs. A missing required value prevents a fidelity claim even if the broad mission is playable.

## C01 Constrictor Hunt

**BBC-derived mission outline [S04]:** Offer on docking in galaxy 1 or 2 at 256 combat points, once only. Route clues lead from Xeer/Reesdice to Arexe, then in galaxy 2 through Errius, Inbibe, Ausar and Usleri to Orarra. Other systems point toward Errius. The target has ECM and military-laser-resistant shielding against weaker lasers. Destruction sets a flag; the assignment pays 5,000 credits and 256 bonus combat points. Bonus timing is port-specific: C64 adds the 256 points on target removal and cash on debrief, with the second point increment disabled in DEBRIEF [S34]. The saved TP low bits progress 00 -> 01 -> 11 -> 10. No explicit deadline is established.

**Version differences:** The BBC disc energy bomb can destroy the Constrictor; later official 6502 profiles cannot [S01]. Oolite requires score >255 and a main station, spawns the target at galaxy index 1/system 193, and clears the player's bounty at debrief [O01]. The MSX disk source uses a 64-arrival assignment scheduler, procedural clue trail, quarter laser damage and a 10,000-credit debrief, plus a separate 400-credit bounty; see the [Z80 profiles](../z80-port-profiles.md) [S41].

**Additional source profiles:** ST uses a generated furthest-system route and five clue hops; GBA has easy-mode thresholds; Oric uses a G4/G5 trail and different rewards. See [classic ports](../classic-port-profiles.md) and [Oric](../oric-mission-specifications.md).

**Project state machine:** unavailable -> briefed -> hunting -> target destroyed -> debriefed. Clue visits are navigational hints, not mandatory checklist stages unless the selected original script proves otherwise. Keep one mission target identity; preserve the destroyed state through save/reload before docking.

**Acceptance scenarios:** 255 points cannot trigger; 256 can in the eligible galaxy. A lookalike ship does not complete the mission. Killing the target does not pay twice. Wrong-system docking before the kill does nothing. Verify bomb immunity under each profile. Specify whether NPC destruction counts from the original target script before implementing that edge case.

## C02 Thargoid Plans

**6502 profile, sourced facts [S05]:** Requires C01 finished, galaxy 3 and TALLY high byte >=5, equivalent to at least 1,280 combat points. Dock to receive the Ceerdi instruction; dock at Ceerdi (215,84) to collect plans; dock at Birera (63,72) to deliver. TP low nibble follows 0010 -> 0110 -> 1010 -> 1110. Carrying plans changes enemy spawning: a Thargoid/Thargon encounter is selected about 22% of relevant spawn checks, not every frame. Reward is a naval energy unit and 256 combat points. No stated deadline.

**Oolite difference [O02]:** Requires score >1280, completed C01 and a main station outside system 83. Collection is system 83; delivery system 36. Initial population adds three Thargoids, with up to two further ambushes during early repopulation. Replace a normal or damaged energy unit with the naval unit and charge fitting time.

**Additional source profiles:** ST delivers documents directly to a generated destination; Oric has its own Rianxe debrief and pursuit hook; GBA has separate easy-mode thresholds and coordinate guards. See [classic ports](../classic-port-profiles.md) and [Oric](../oric-mission-specifications.md).

**Project state machine:** unavailable -> summoned -> carrying -> delivered. A source-station visit before summons must not issue plans accidentally. Activate pursuit only while carrying. On delivery, remove mission pursuit hooks and award equipment once. Plans are mission data unless the chosen profile defines physical cargo; do not assume they occupy one tonne.

**Acceptance scenarios:** completed C01 plus 1,279 points fails the BBC gate; 1,280 passes BBC but not the inspected Oolite >1280 gate. Birera before collection cannot complete. Save/reload while carrying retains pursuit. Repeated Birera docking cannot award duplicate equipment or points.

## C03 Trumble infestation

**C64/NES profile [S06]:** A merchant offer costs 5,000 credits, seeds one creature, and is offered once. Creatures multiply during jumps and flight, consume food, and in C64 also consume narcotics. C64 displays canopy sprites; NES calls them Little Squeakys and omits canopy sprites. Sun heating kills them; an escape capsule does not cure the infestation. The threshold disagreement is resolved for the inspected source: C64 tests a single cash byte, so eligibility wraps; NES tests the high cash bytes and needs >=6,553.6 credits. The complete purchase, register-level breeding, cargo and heat rules are in [classic port profiles](../classic-port-profiles.md), S34/S35.

**Oolite offer profile [O05]:** At a main station, eligible offers have 20% probability and need >6,553.5 credits; purchase costs 30 credits. Refusal can reset at 2% per jump. Nova progress suppresses offers. This offer script does not define breeding or heat constants.

**Project states:** unoffered -> offered -> refused or infested -> cured. Persist population, consumed goods and offer history. The original no-refund outcome is not a cash reward. Track reproductive tick cadence separately from rendering frame rate.

**Acceptance scenarios:** decline never deducts money; accept deducts exactly once. Escaping does not reset population for C64/NES. High heat reduces population while ordinary temperatures do not. A save with one creature remains infested. Use the supplement for population overflow, heat 240, RNG carry, cargo clearing and escape survivors; original loop cadence and visuals still require the selected engine profile.

## C04 Supernova rescue

**Oolite profile [O03]:** Galaxy 4, more than three counted entries, a working galactic drive and ordinary space trigger the emergency. A fuel leak and two-hour nova timer encourage docking at the main station. Accepting loads refugees, launches the player, destroys stations and reduces the timer to 30 seconds; refusal gives nine seconds. Successful escape then main-station debrief in galaxy 4 or 5 clears special cargo and grants 100 units of gems. Escape-pod use and refusal have separate outcomes; refusal harms contract/passenger reputation. The devastated system persists.

**ST source:** 64-jump scheduler, cargo cleared even on refusal, raw gemstone overwrite and sun progression are specified in [classic ports](../classic-port-profiles.md).

**Other ports:** The identified MSX disk source clears cargo even on refusal and replaces the gem quantity with 50 grams at successful debrief; the earlier 50 kg report is superseded [S41]. Escape-drive and scene parity still require fixtures. The [Z80 profiles](../z80-port-profiles.md) also establish the Spectrum compatibility release's 100-gram replacement and selected 256-point awards [S42]. PC Plus rescues refugees to another system and reports cash [S09]. Do not universalise Oolite's jump count, countdowns or reward.

**Project states:** dormant -> emergency -> accepted/refused/ignored -> escaped/lost passengers -> debriefed. Persist destruction separately from mission progress. Record whether local or galactic jumping is valid for each profile. Preserve capacity and cargo replacement behaviour; do not assume ordinary passenger cabins are required in classic Elite.

**Acceptance scenarios:** saving cannot reset the nova timer. Leaving without docking follows the ignored path. Accepting cannot leave stations available as an escape-pod loophole. Successful hand-in grants gems once. Test refused, ignored and escape-pod outcomes separately.

## C05 Cloaking device

**MSX disk profile [S41]:** A scheduled Cougar attack awards a separate 500-credit bounty; destroy it and scoop its special dropped container for the cloak. The scoop path requires fitted scoops and the correct approach, bypassing ordinary full-hold checks. See [Z80 profiles](../z80-port-profiles.md). **PC Plus [S09]:** A nearby-system encounter uses three cloaked Asps with supporting Cougar/Constrictor craft; recover a device and return to the issuer. **Oolite [O04]:** In galaxy 5, counter >6 can populate a cloaked Asp group at the arrival point while the encounter is unresolved. Equipment and pod scripts determine acquisition; they must be checked alongside the mission script.

**ST source [S36]:** the Cougar drops one negative-type equipment canister when allocation succeeds; a fuel scoop and the correct approach fit the cloak, even with a full ordinary hold. Removing the Cougar ends the mission independently of recovery. Exact header statistics, frame-counter cloaking and acquisition branches are in [classic ports](../classic-port-profiles.md).

**Project states:** eligible -> encounter spawned -> carrier destroyed -> device recovered -> fitted/debriefed. A destruction bounty is separate from acquiring equipment. Keep the drop unique and persist whether it was recovered or lost. BBC-MASTER's ordinary cloaked Cougar is a ship behaviour, not proof of this mission.

**Acceptance scenarios:** kill without scoop does not award a scoop-based cloak. Unrelated cargo does nothing. A cloaked target's visual/scanner treatment follows its profile. Exact respawn-after-lost-pod and equipment energy consumption remain unresolved for several ports.

## C06 Thargoid occupied station

**Reported behaviour [S07, S09]:** Assign an invaded system, increase Thargoid opposition, make the occupied station destructible, then require docking elsewhere or return to the issuer for an ECM jammer/anti-ECM reward. PC Plus also reports an Archangel status and possibly adverse legal effects; those require binary verification.

**ST source:** next-destination occupation, 200-frame reinforcement counter, Dodecahedron station and ECM-jammer debrief are in [classic ports](../classic-port-profiles.md).

**Project states:** assigned -> invaded system -> station destroyed -> reported. The mission changes one station instance's invulnerability; ordinary stations remain protected. Remove hostile occupation only for the selected target. Keep reward, legal changes, galaxy selection, station hull, spawn rate and exact debrief location in per-port configuration. Those numerical values remain unresolved.

**Acceptance scenarios:** destroying a different station does not complete; target destruction without debrief does not pay; ordinary stations do not become destructible globally; save/reload preserves the target's loss.

## C07 Stolen Police Ship

**PC Plus [S09]:** A named-system search-and-destroy assignment with cash payment. Target type, cash, counters and respawn rules require a binary/playthrough fixture.

**Project sequence:** offer -> accept -> enter target system -> identify unique stolen craft -> destroy -> debrief. Separate this from C01: a similar hunt is not evidence of the Constrictor script. Acceptance scenarios must include innocent police craft, target escape, wrong location, issuer return and repeated debrief.

## C08 Asteroid Bombardment

**PC Plus [S09]:** A named system has extra asteroids, including near its station; sufficient destruction leads to cash on docking. The exact quota, placement, clock, laser requirements and payout are unresolved.

**GBA-TNK source [S37]:** repeatable 30-asteroid assignment, 6,000-credit reward, off-target asteroid credit, exact spawn rules and initial-destination defect are in [classic ports](../classic-port-profiles.md). These facts do not establish PC-PLUS parity.

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

The [Oric specification](../oric-mission-specifications.md) supplies R01-R10, T01-T04 and the Oric C01/C02 profiles. It includes the branching campaign, every mission file, cargo quantities, destination indices, encounter positions, counters, completion callbacks and failure byte. Keep its source rewards and tutorial retries separate from BBC and ST profiles.

## First Encounters campaign model

FFE follows a simulation calendar, not the player's real date. News and offers advance even if a player ignores them. Persist role decisions: F04 and F07 are mutually exclusive. Do not require all missions in a single run. The reportable bug behaviour depends on original patch or JJFFE. Exact target departure times and generated starports should be captured from the chosen build. [S14, S15, S16, S39, S43, S44]. The [journal and save profiles](ffe-journal-and-save-profiles.md) provides the source calendar, journal dependencies and six verified static checkpoints. The [FFE source supplement](first-encounters-source-notes.md) records interpreter findings, raw script graphs and exact predicates while preserving unresolved semantics.

The following entries contain factual itinerary parameters followed by project acceptance conditions. In all cases save the accepted contract's scheduled dates rather than recalculating them. Unspecified instance values must be read from the original contract or a fixture.

## F01 Wiccan Ware Race

**Source-profile correction [S39]:** winning prize is generated in the range 1,000-1,999 credits, with a much smaller runner-up branch. The inspected script reads an uninitialized deadline local. Exact source branches and the unresolved runtime defect are documented in [FFE source evidence](first-encounters-source-notes.md).

Historical parameters: January-February 3250; Old Curie/Gateway to Ghandi/Wicca's World/Alioth; 1,010 credits and reputation. Ranking uses journey time, not simply earliest calendar acceptance. [S14, S15]

Implement as accepted -> recording onboard -> arrival -> evaluated. Persist start time and the winning travel-time cutoff; the exact cutoff is unresolved. Reject wrong-port hand-in and pay only once. Test losing travel time, delayed acceptance with fast travel, multi-jump route and reload without clock reset. The recording is a unique mission payload, not generic entertainment cargo.

## F02 Soholia Medicine Relief

**Source-profile correction [S39]:** a newly opened buyer dialogue pays 2,000 credits for its first medicine unit, then 3,600 for repeated sales within that dialogue. The market override is separate. See [FFE source evidence](first-encounters-source-notes.md) for the 56-day relative window and exact payment propagation.

Historical parameters: early 3250; deliver medicines through Soholia's special bulletin-board demand; reported 2,000 credits per tonne plus reputation. [S14, S15]

Implement as a temporary demand event, with repeat sales during its valid period rather than a one-off unique package. The special advert and ordinary commodity market are different endpoints. Test quantity removal, payment per delivered tonne, event expiry and selling elsewhere. Freeze price and reputation formula from the selected build before claiming exact parity.

## F03 Duval Artefact

Walkthrough parameters: Checkovport/Achenar pickup on 14 March 3250; Scott Town/Beta Hydri by 4 April; 6,000 credits. The S43 ARTWORK checkpoint instead gives 25 February at noon for the S39 pickup expression; its loaded-delivery phases contain no date check. Keep the [source/save graph](ffe-journal-and-save-profiles.md) separate from those reported dates. News later identifies the artwork as stolen. [S14, S15]

States: accepted -> waiting pickup -> loaded -> delivered/late. Test early arrival and waiting across pickup time, wrong-port landing, payload loss, deadline boundary and one payment. Preserve the later news consequence independently from immediate delivery success. Do not deduct a theft penalty unless confirmed in the selected build.

## F04 Assassinate Dentara Rast

Historical parameters: offers from late August 3250; attack in early December; 50,000 credits. The target must die before hyperspace. Player becomes the subject of adverse press and pursuit. [S14, S16]

States: contracted -> departure scheduled -> intercepted -> killed before escape/escaped -> reported. Target escape permanently fails this instance even if its ship is later destroyed. Record the player-as-assassin flag so F07 cannot be offered to the same player. Test departure-time boundaries and persistence of subsequent news/pursuit.

## F05 Assassinate Dr Joreb Innitu

Historical parameters: February 3251; target at Fort Grant/Beta Hydri; 1,500 credits and the employing navy's medal. Must kill before hyperspace; return to issuing system can pay without docking. [S14, S16]

Use the assassination state machine but a system-entry reward trigger. Store employing faction and medal eligibility. Test entering the wrong system, returning without a kill, post-hyperspace destruction and repeated system entries. Do not force a docking requirement borrowed from ordinary contracts.

## F06 The Two Hitchhikers

Historical parameters: two cabins; Urtize by 25 March 3251, followed by Edethex/Singh by 17 June; 6,000 credits. Missing their schedule can cause destruction. The guide mentions both Solo's Rock and Moore Starport for Urtize; exact staging must be verified. [S14, S15]

Use two passenger identities and two legs with separate pickup/arrival events. Test one cabin, one passenger missing, wrong intermediate port and both deadlines. S39 script 42 supports two cabins, 6,000 credits, reputation +5 and distinct station object seeds; its text names Solo's Rock and Finn in Edethex. S43 binds the displayed schedule to 25 March/20 May/17 June, but phase 7 fails after t+140 days (12 August in this save). The [detailed graph](ffe-journal-and-save-profiles.md) records the intervening warnings and destructive timers. Resolve station names, raw action semantics and successful/failed runs before fidelity sign-off.

## F07 Hunt Dentara Rast's assassin

Historical parameters: March offer, April 3251 execution; 50,000 credits; unavailable when the player performed F04. [S14, S16]

Generate a separate NPC assassin only when the player is eligible. Carry F04 history into offer selection. Test that player-as-assassin never receives a self-target contract, while declining F04 allows this alternative. Bind kill credit to the advertised target and departure schedule.

## F08 Visitor to Thompson's Planet

Historical parameters: June 3251; one cabin; Thompson's Planet/Ackwada; 6,000 credits. Any surface starport on that planet satisfies the reported destination. [S14, S15]

Use a planet destination predicate rather than a specific station. Test multiple valid surface ports, an orbital station in the same system, no cabin, lost passenger and repeat payment. Keep its narrative association with F09 without inventing a prerequisite between the two.

## F09 Rockforth Legal Academy

Historical parameters: June offer, attack on 16 July 3251; Ackwada; 10,000 credits; fighter-defended academy. [S14, S16]

Use a named surface-installation destruction objective. Distinguish visual damage from the actual destroyed flag. Test nearby buildings, partial damage, correct target, late arrival and defensive spawns. Target coordinates, hull, missiles needed and wave sizes remain fixture requirements; do not use the walkthrough's weapon advice as a coded success rule.

## F10 Junior's Friend

Historical parameters: June 3251; one passenger cabin; Fort Cousens/Liaququ pickup, Edmonds/Fawaol delivery; 2,000 credits. The passenger is a dolphin. [S14, S15]

The [S39 source profile](ffe-journal-and-save-profiles.md#f10-juniors-friend-delivery-condition) now establishes offer publication, randomized pickup deadline, cabin check, exact destination seeds and the full/half-payment rule. Delivery condition is a random remainder using elapsed transit, with full payment guaranteed for positive intervals through five days; the injured message does not test a dolphin-health field. The accepted script does not reserve a cabin. Preserve these rules and helper lifetimes separately from an adapted passenger model; verify original scenes and outcome saves.

## F11 Five Furies

Historical parameters: March 3252 offer; cabin required despite statue cargo; Fort O'Brien/Cemiess to Oliverport/Epsilon Eridani; 2,000 credits. Displayed timing is reported incorrect. [S14, S16]

S39 now establishes the [displayed and effective schedule](ffe-journal-and-save-profiles.md#f11-five-furies-effective-pickup-and-reward-rules): generated t is publication-relative, advertised pickup t-3 days, effective pickup no later than t-2 days, and no earliest-pickup wait. Delivery requires a specific seed and state 42; it pays 2,000 even when late, with reputation +5 only through t+1 day. The source contract does not check or reserve a cabin, conflicting with the historical report. Preserve these profiles separately; verify an original contract save before assuming binary parity.

## F12 Jan Thikka rescue

Historical parameters: March 3252 offer; mid-August pickup at Camp Campbell/New America/Miargre; Wafaphi Federal base delivery; 2,000 credits and one Federal promotion. Pickup day can vary. [S14, S15]

The [source graph](ffe-journal-and-save-profiles.md#f12-jan-thikka-boarding-negotiation-and-promotion-defects) now fixes a closed one-day boarding window, cabin check at boarding, any-Federal-system hand-in and no return deadline after boarding. It also exposes an untransferred promised advance, a docked timeout stall and signed-byte Federal-point truncation that can demote the player instead of promoting them. Preserve these source bugs separately from deliberate repairs. Test every timer equality, berth change, negotiation branch, Federal-point boundary and save/reload transition. Original-game outcome fixtures and generated Camp Campbell scene binding remain required.

## F13 Argent's Quest first expedition

Historical parameters: Turner's Requiem, 5 October 3252; Alioth; Competent; 10,000-credit donation. Grants Argent's Quest and reported cash doubling. Pleione (32,32), planet 4b, contains the defence satellite, Turner's wreck and recorder; photographs within 10 km are reported. Return before approximately mid-December. [S14, S15, S16]

States: eligible -> donation -> ship transferred -> satellite disabled -> evidence collected -> return. The recorder selects direct F15; missing it selects F14. Persist the old ship transaction and grant once. Capture exact deadline, cash transaction order, photo counts and jammer/nuclear-missile mechanics from the original build. A reported missile-on-launch bug is not a core mission requirement.

## F14 Red Square Flowers

Historical parameters: fallback after F13 without recorder; Werner Starport/Gold/Liaethfa; contact flora/fauna advert, collect agent, return Alioth; no stated payment. [S14, S15]

States: fallback offered -> contact found -> agent boarded -> escaped -> returned -> F15 eligible. Test that a recorder-bearing return skips this branch. Keep U01 distinct. S39 supplies a 28-day advert lifetime, a 30-second response window, a separate ten-second arrest branch and exact Alioth/station object-seed predicates in the [source supplement](first-encounters-source-notes.md). S43 directly binds its Alioth return seed to New Rossyth; full termination/outcome semantics still need fixtures.

## F15 Argent's Quest second expedition

Historical parameters: after F13 recorder or F14; New Rossyth/Alioth to Polaris (0,76), defence satellite at Polaris 3d, dock with alien shuttle, transit to Miackce, then dock with main Thargoid vessel. [S14, S15, S16]

States: assigned -> satellite disabled -> shuttle docked -> relocated -> contact -> F16. Preserve coordinate relocation and the player's ship contents. Hostility is not assumed merely because Thargoids appear. Test alternate entry histories, wrong satellite, docking before clearance, hostile action and reloading after relocation. Source discrepancies on coordinates require build-specific data.

## F16 Mycoid vaccine

Historical parameters: Miackce briefing; MB4 supplied; Hotice (-3,-2), planet 1 vaccine installation; destroy dome, deploy MB4 and retrieve vaccine; return to Thargoids; offered alien warship, then return Alioth/New Rossyth. [S14, S15, S16]

States: commissioned -> facility opened -> vaccine extracted -> vaccine onboard -> returned -> ship offered -> built -> Alliance debrief. Test empty MB4, failure to recall it, missing vaccine, reward refusal and one ship replacement. The alien ship's missing navigation/autopilot/atmospheric shielding and cargo overflow are build-specific compatibility details, not safe generic equipment defaults. Record exact reward cargo before reproducing overflow.

## U01 to U05 unfinished branches

Surviving FFE text suggests U01 message transport, U02 delivery of a renewed mycoid weapon, U03 an interception replacing vaccine with weapon, U04 pursuit of a stolen vaccine and U05 assassination followed by identity replacement. S17 reports these as unfinished; S39 now supplies embedded scripts, but related branch reachability and completed outcomes have not yet been proved. Do not convert a walkthrough claim into a source-code absence claim.

These cannot be faithfully replicated as completed retail missions. An optional reconstruction can use transport, interception, tracking and identity-change mechanics, but must provide original project decisions for every trigger, location, choice, consequence and reward. Never merge U01 into F14 solely because both involve flowers. Acceptance condition: cut content is disabled in a retail-parity profile and clearly marked reconstructed when enabled.

## D01 Decoding the Ancient Ruins

**Reported research profile [source:D01]:** Dock at Felice Dock/Meene to acquire the research assignment. Use an SRV data-link scanner at Guardian ruin obelisks while carrying the required artefact combination. Collect 101 distinct logs; a 28-day limit and partial hand-in apply. Reported historical payout is one million credits per log plus ten million for completion; freeze the chosen build because values changed historically.

Represent each log as a unique ID mapped to site/layout/obelisk and a multiset of inventory items, not an ordered pair. States: assigned -> scanning -> hand-in -> paid. Persist unique scan IDs; repeat scans cannot multiply rewards. Exact combinations belong in a versioned content table sourced from Canonn, not an improvised puzzle generator. The full 101-log route table, eleven site blocks, artefact multisets and historical site/obelisk records are now supplied in [Guardian mission data](guardian-mission-data.md) and its JSON datasets [D16, D18]. Live coordinates and original bonus values still require a selected-build check.

**Acceptance scenarios:** reversed item order succeeds; wrong combination fails; previously collected log does not increment; partial return pays only found logs; completion bonus paid once; timer survives save/offline behaviour appropriate to the original profile.

## D02 Decrypting the Guardian Logs

**Reported profile [source:D02]:** Mitchell Dock or Weber Dock/Meene; no Ram Tah engineer unlock required. Four weeks, 28 unique logs, one million credits each plus 30 million completion bonus; partial hand-in and repeat attempts are reported. Visit Guardian structures, not the earlier ruins. Required items include Guardian artefacts and corrosive Thargoid sensor/link/probe and tissue samples from Cyclops, Basilisk and Medusa.

Reuse D01's unique-log model with a separate content table and mission identity. Include Sentinel threats and cargo corrosion. The same artefact pair can yield different logs at different layouts. All 28 log/item/layout mappings and their listed obelisks are now supplied in [Guardian mission data](guardian-mission-data.md) and JSON [D17, D18]. Historical coordinates and verification flags remain distinct from current Live scene evidence.

**Acceptance scenarios:** starting D02 does not overwrite D01's progress; large-pad-only ships cannot dock at the outpost; repeated logs do not pay again; 27 logs gives no completion bonus; 28 does; expiry, cargo destruction and partial hand-in produce the selected build's results.

## D03 to D09 Operations

**Documented scenario identities [source:D05]:** D03 clears criminal combat stages; D04 boards a compromised megaship, gathers intelligence and pursues a commander; D05 breaks a siege and evacuates a burning station; D06 evacuates a port before hostile fleet arrival; D07 retakes a hijacked megaship; D08 attacks a research operation and its responsible personnel; D09 breaks a blockade, retakes a settlement and faces another ship threat.

**Shared project model:** scenario -> squad ready -> deployed -> ordered stages -> extraction/completion or failed. Store difficulty, participation mode, checkpoint, stage objectives, enemy wave index, casualties, evacuees, timers and Operation Runner state. Mercenary and Powerplay are distinct modes. Individual rewards and Powerplay eligibility cannot be inferred from ordinary mission boards.

Each named scenario needs an observed stage graph, map, NPC roster, wave conditions, timers, extraction rules and payout before fidelity. The inspected source is explicitly partially verified. The [Operations supplement](operations-evidence.md) supplies observed sequences, official release boundaries and explicit report conflicts. Tests must cover premature stage completion, late joins/disconnects, redeployment, failed evacuation, squad completion and duplicate payouts. These are fidelity requirements: D03-D08 have R2 observed sequences but remain R3 for exact simulation parity; D09 remains R3.

## Generated objective implementation recipes

These recipes support G01-G24 with explicit parameters. They make an original game implementable; reproducing a particular game's generator additionally requires its offer distribution, arithmetic, reputation gates and original content data.

| IDs | Required parameters | Sequence and success predicate | Failure and acceptance cases |
| --- | --- | --- | --- |
| G01 | person ID, information contacts, price, destination hint | Query matching contact; pay if required; reveal clue or complete enquiry. | Wrong identity never completes; information purchase cannot duplicate charge on reload. |
| G02 | issuer, payload ID, origin, destination, deadline | Accept unique data/package; deliver to correct contact. | Expiry, abandonment and specified payload loss; wrong station and unrelated goods cannot complete. |
| G03 | supplied/procured flag, commodity, quantity, destination, provenance rule | Load supplied cargo or acquire commodity; deliver required amount. | Supply rules differ from ordinary market substitution; persist partial deliveries and recompute remaining quantity safely. |
| G04 | destination coordinates, initial reward, fee, legal increment | Elite-A: accept/pay; on intermediate docking halve stored reward; destination docking pays remaining reward/10 credits and clears it. | Reward reaching zero ends the job. Hyperspace alone does not halve it. See S10 and the notes below. |
| G05 | passenger IDs, cabins, pickup, destination, deadline, risk | Board only with capacity; transport named passengers; disembark. | Passenger loss/expiry and contract-specific hostility; test ship exchange and cabin removal. |
| G06 | VIP, cabin class, ordered beacons, destination, demands | Board; satisfy scan itinerary; return or deliver. | Track scans in order where required, satisfaction and optional demands separately. |
| G07 | unique target, route/schedule, kill-credit rule, issuer | Locate; destroy/kill allowed target; report. | Escaped target, wrong victim, civilian penalties and on-foot rules; story-specific pre-jump requirements override generic pursuit. |
| G08 | faction/target class, quota, valid region, credit sharing | Count qualifying kills until quota; report. | Unrelated kills and duplicate kill events do not count; wing sharing is explicit. |
| G09 | installation, camera, maximum distance, deadline | Photograph valid target with correct equipment; return data. | Wrong object, too far, missing camera, late return; damage does not substitute for photograph. |
| G10 | installation ID, location, hull/destruction flag, deadline | Reach target; destroy it; report to navy. | Wrong structure, partial damage, escape/late report; military rank and medals are separate reward fields. |
| G11 | recon objective plus satellite, jammer and nuclear missile | Neutralise/avoid reporting mechanism as profile requires; gather evidence; return. | Sensor/jammer timing and disclosure must be sourced; do not universally make nuclear destruction mandatory without evidence. |
| G12 | victim/hostages, containers, legal basis, quantity | Find vessel; release/scoop correct cargo; hand in. | Killing hostages, generic lookalike cargo, expiry and legal consequences. |
| G13 | wreck/site ID, recoverable item IDs, quantity | Locate mission signal/site; recover; deliver. | Unique provenance, surface/space retrieval and loss; unrelated black boxes never substitute by name alone. |
| G14 | data point/terminal, access rights, scan/download duration | Locate and interact; hold required access; capture data. | Alarm/timeout only if specified; wrong terminal and interrupted download do not finish. |
| G15 | target terminal, upload item, access, duration | Infiltrate; upload mission-specific data; extract/report. | Wrong terminal, missing payload, alarm or violence constraints; uploading twice does not duplicate success. |
| G16 | generator/process/container, sabotage method, access | Reach correct device; destroy or insert sabotage payload. | Similar nearby devices are not sufficient; alarm and collateral rules remain constraints. |
| G17 | item ID, locker/sample unit, code, containment timer | Gain access; release container; acquire unique item; return. | Theft and heist share acquisition but heist has container procedure; alarm/nonviolent variants remain constraints. |
| G18 | settlement, regulator, authorised access, fires | Install power regulator; restore power; extinguish specified fires. | Reactor state alone cannot satisfy restore-with-fires; lost regulator, remaining fire, death and abandonment handled explicitly. |
| G19 | settlement, enemy IDs/classes, waves, defence asset | Clear or defend until objective graph completes. | Innocent occupants, reinforcements and wrong faction; asset loss only fails where required. |
| G20 | commodity, extraction requirement, amount, delivery | Mine/refine permitted resource; deliver. | Buying may not count if provenance is required; partial deliveries use exact mass units. |
| G21 | currency or commodity, amount, recipient | Transfer atomically; apply reputation/influence. | Insufficient funds/items makes no partial mutation unless allowed; no invented cash reward. |
| G22 | evacuees/pods, capacity, danger, destination, deadline | Embark/scoop; survive; deliver survivors. | Distinguish cabin evacuees from cargo pods; casualty count, station hazards and rewards must be configured. |
| G23 | clue, coordinates, site, discovery predicate, data reward | Follow tip; locate site; scan/recover specified evidence. | Wrong site, expired message and revisiting an already credited object. |
| G24 | alien vessel class, region, quota, credit rules | Destroy only designated alien targets; report if required. | Human kills never count; AX encounter variants, event availability and kill sharing are separate profile fields. |

### Elite-A generator fidelity

S10 establishes that the menu remains stable during a station visit and that delivery state stores reward plus destination coordinates. It is regenerated after relevant market/ship state changes. Acceptance costs a fee and may add to legal status; intermediate docking right-shifts a 16-bit reward. A generic continuous clock penalty is incorrect.

For exact offers, use the pinned original `cour_buy`, `cour_count`, `cour_dock` and commander-save arithmetic linked in S10. Required remaining work: transcribe wrapping byte operations, seeds, distance rounding, fee/reward construction and legal-status effects into fixtures. Test an all-sun-scooping journey against one with intermediate docking; merely flying farther or waiting must not halve the reward.

## Oolite expansion campaigns

P01-P48 are optional mission packs catalogued in [missions](../missions.md). A pack can contain many missions, custom systems, ships and scripts. Base-game C01-C05 state machines do not supply their plots. To reproduce a pack, freeze its version and create a stage graph with the required fields above for each sub-mission; identify every script timer, random branch, target, equipment dependency and persistent mission variable.

The [expansion supplement](../oolite-expansion-specifications.md) specifies P03/P04/P09/P18/P23/P25/P26/P27/P33/P35/P36/P37/P38/P40/P41/P42, including branches, rewards, deadlines, encounters and source quirks. P40 ends at a published continuation notice; P26 distinguishes historical 2.5.3 from the source-blocked 3.0 finale. Its [package manifest](../data/oolite-pack-sources.json) freezes 39 downloaded package revisions and file hashes. Combat resources and selected Oolite engine semantics are recorded separately. Other pack entries remain discovery records, and even an R1 core graph still requires its engine/resources for exact parity. Preserve known dependencies from O06, including native-mission prerequisites and deprecated compatibility. In particular, Asteroid Storm is a distinct campaign from C08 despite a similar theme. Do not invent campaign endings from names such as Cataclysm or Iron Raven.
