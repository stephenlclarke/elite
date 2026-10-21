# Deduplicated mission catalogue

Version IDs are defined in [versions](versions.md). An appearance lists a supported edition, not every presumed derivative. Readiness levels R1/R2/R3/U are defined in [coverage](coverage.md). Canonical story missions link to the [main specification](mission-specifications.md) or the detailed port supplements below. Readiness is specific to the inspected profile, not every edition in a row. Sources identify the relevant original reference in [sources](sources.md).

**Active scope:** Frontier/First Encounters, every Elite Dangerous Operation, Guardian surface/SRV assignments and other ground/on-foot objectives are excluded. [Scope and per-family restrictions](implementation-scope.md) govern this catalogue; archived discoveries do not authorize implementation.

A retained campaign ID is an inventory entry. Each individual playable mission must pass the space-only check: space-only objectives and explicitly mapped station handoffs for original planetside stages. Keep eligible space missions within mixed campaigns; preserve their excluded siblings as research only. All research permissions remain in force.

## Classic mission families

| ID | Canonical mission and aliases | Confirmed or reported versions | Readiness | Sources |
| --- | --- | --- | --- | --- |
| C01 | Constrictor Hunt | BBC-DISC, BBC-SP, BBC-MASTER, BBC-COMPACT, C64, APPLE2, NES; ST source, GBA-TNK source, ORIC1337 source; MSX-DISC source; reported AMIGA; OOLITE | R1/R2 | S01, S04, S07, S08, S34, S36, S37, S38, S41, O01 |
| C02 | Thargoid Plans / Documents | BBC-DISC, BBC-SP, BBC-MASTER, BBC-COMPACT, C64, APPLE2, NES; ST source, GBA-TNK source, ORIC1337 source; MSX-DISC source; reported AMIGA, PC-PLUS; OOLITE | R1/R2 | S01, S05, S07, S08, S36, S37, S38, S41, O02 |
| C03 | Trumbles / Tribbles / Little Squeakys | C64, NES; reported PC-PLUS; OOLITE | R1 C64/NES core; R2 other profiles | S06, S08, S34, S35, O05 |
| C04 | Supernova / Nova / Refugee Rescue | ST/MSX-DISC source; ZX128 source/tape; OOLITE; reported ZX48, CPC, PC-CGA, PC-PLUS, AMIGA | R1/R2 | S07, S08, S09, S36, S41, S42, O03 |
| C05 | Cloaking / Masking Device / Cougar encounter | ST/MSX-DISC source; ZX128 source/tape; OOLITE; reported ZX48, CPC, PC-CGA, PC-PLUS, AMIGA | R1 ST core / R2 ports | S07, S08, S09, S36, S41, S42, O04 |
| C06 | Thargoid Invasion / Captured Station | ST/MSX-DISC source; ZX128 source/tape; reported CPC, PC-CGA, PC-PLUS, AMIGA | R1 ST core / R2 ports | S07, S08, S09, S36, S41, S42 |
| C07 | Stolen Police Ship | PC-PLUS | R2 | S08, S09 |
| C08 | Asteroid Bombardment | PC-PLUS reported; GBA-TNK source | R1 GBA core; R2 release/start data and PC-PLUS | S08, S09, S37 |
| C09 | Genesis Capsule | ARC, ARC-GOLD | R2 | S08, S40 |
| C10 | Kill Zartid III | ARC, ARC-GOLD | R2 | S08, S40 |
| C11 | Kill Zurid Pino | ARC, ARC-GOLD | R2 | S08, S40 |
| C12 | Medicine Run | ARC, ARC-GOLD | R2 | S08, S40 |

BBC-TAPE and ELECTRON have no scripted story missions. A cloaked ship in BBC-MASTER is not a separate C05 assignment. ARC's campaign replaces the naval missions rather than proving their presence. The identified ZX128 scheduler and selected outcomes are now confirmed in S42; complete mission paths remain R2. EINSTEIN, PC98, PLUS4 and other TNK derivatives require separate confirmation. ELITE-A's special deliveries are G04; inherited naval scripts remain unverified here. [S01, S08, S10](sources.md)

## Oric 1337 unique assignments and tutorials

All entries below are ORIC1337, source S38, R1 core graph / R2 disk and engine parity. Full prerequisites, destinations, cargo quantities, encounter positions, branches, rewards and state bytes are in the [Oric specification](oric-mission-specifications.md). C01 and C02 retain their existing IDs instead of being duplicated here. Names below are descriptive labels based on the mission code, not asserted official menu titles.

| ID | Assignment or tutorial | Source file |
| --- | --- | --- |
| R01 | Milto Zaxx food delivery | mission0 |
| R02 | Xexedi food delivery and legal diversion | mission1 |
| R03 | Teraed narcotics delivery | mission2 |
| R04 | Intergalactic machinery delivery | mission3 |
| R05 | Rescue Maynard Zantor | mission4 |
| R06 | Pirate ambush and Untha Banhath meeting | mission5 |
| R07 | Garmond Hasler briefing at Riave | mission6 |
| R08 | Recover the cloaked container | mission7 |
| R09 | Defend Edorqu from asteroids | mission8 |
| R10 | Hunt Torjan Mino | mission11 |
| T01 | Flight and docking tutorial | tutorial0 |
| T02 | Splinter shooting tutorial | tutorial1 |
| T03 | Adder combat tutorial | tutorial2 |
| T04 | Zaonce navigation and trading tutorial | tutorial3 |

## Generated objective families

These are reusable mechanics, not additional copies of each story mission. Frontier and ground/on-foot variants are excluded. Sources: [S10, S18, D03, D04](sources.md).

| ID | Objective family | Versions supported by the references |
| --- | --- | --- |
| G02 | Data or package courier | ED-LIVE, ED-LEGACY, OOLITE |
| G03 | Supplied freight delivery or commodity procurement | ED-LIVE, ED-LEGACY; OOLITE freight contracts |
| G04 | Special cargo with docking-dependent payment | ELITE-A |
| G05 | Passenger transport | ED-LIVE, ED-LEGACY, OOLITE |
| G06 | VIP sightseeing or expedition | ED-LIVE, ED-LEGACY |
| G07 | Assassination of a named ship | ED-LIVE, ED-LEGACY |
| G08 | Massacre or target-count combat | ED-LIVE, ED-LEGACY |
| G12 | Theft or liberation of cargo and hostages | ED-LIVE, ED-LEGACY |
| G13 | Space salvage and recovery | ED-LIVE, ED-LEGACY |
| G14 | Ship-based data scanning or download | ED-LIVE, ED-LEGACY |
| G16 | Ship-based installation or process sabotage | ED-LIVE, ED-LEGACY |
| G20 | Asteroid mining from ships and delivery | ED-LIVE, ED-LEGACY |
| G21 | Credit or commodity donation | ED-LIVE, ED-LEGACY |
| G22 | Passenger evacuation and survivor rescue | ED-LIVE, ED-LEGACY; event availability differs |
| G24 | Designated anti-xeno combat | ED-LIVE; historical ED-LEGACY availability differs |

Smuggling is a legality condition on cargo; covert and nonviolent are objective constraints; team/wing and chained contracts describe participation and sequencing. Keep those attributes rather than duplicate every combination. Free exploration, trading and bounty hunting are not automatically contracts.

## Oolite optional campaigns

All P entries are OOLITE-OXP. P03, P04, P09, P18, P23, P25, P27, P33, P35, P36, P37, P38, P41 and P42 have analysed core graphs in the [expansion specification](oolite-expansion-specifications.md); Ionics battle compatibility remains R2. P26 has a historical 2.5.3 graph and a distinct 3.0 spawn blocker. P40 has a documented published portion ending at an unfinished continuation notice. P01 and P48 also have dedicated source specifications linked below. Other entries remain R3 discovery records. [O06, O07](sources.md). Availability and mechanics depend on installed package versions.

| ID | Pack or campaign | Indexed galaxy | Indexed kills | Other prerequisites | Detail source |
| --- | --- | --- | --- | --- | --- |
| P01 | Assassins Guild | G7 | 200 | Not stated | [Pack page](https://wiki.alioth.net/index.php/The_Assassins_Guild_OXP) |
| P02 | Aquatics - The Kraken IV | G3 | Not stated | Good standing with the Corporation | [Pack page](https://wiki.alioth.net/index.php/Aquatics_OXP) |
| P03 | Asteroid Storm | G1 | 64 | Not stated | [Pack page](https://wiki.alioth.net/index.php/Asteroid_Storm) |
| P04 | Bank of the Black Monks | any | Not stated | Not stated | [Pack page](https://wiki.alioth.net/index.php/Black_Monk_Monastery) |
| P05 | Blackjack's Bullion | G2 | Not stated | Not stated | [Pack page](https://wiki.alioth.net/index.php/BlackjacksBullion_OXP) |
| P06 | Cataclysm | G1 | >=5120 in2.0source | Finished Thargoid Plans | [Pack page](https://wiki.alioth.net/index.php/Cataclysm_OXP) |
| P07 | Coyote's Run | G5 | Not stated | Cloaking Device | [Pack page](https://wiki.alioth.net/index.php/Coyote%27s_Run) |
| P08 | Curse of the Black Sunspot | G3 | 512 | Not stated | [Pack page](https://wiki.alioth.net/index.php/Curse_of_the_Black_Sunspot) |
| P09 | Deposed | G4 | 1694 in inspected 2.1; index says 1700 | Part 2 requires 1824; several refusal/nova branches stall in source | [Pack page](https://wiki.alioth.net/index.php/Deposed_OXP) |
| P10 | Escort Contracts | any | any | Clean legal status | [Pack page](https://wiki.alioth.net/index.php/Escort_Contracts_OXP) |
| P11 | Feudal States | any | Not stated | Not stated | [Pack page](https://wiki.alioth.net/index.php/Feudal_States) |
| P12 | The Galactic Almanac | G1 | any | Must also have GNN News Installed | [Pack page](https://wiki.alioth.net/index.php/The_Galactic_Almanac_OXZ) |
| P13 | Galactic Navy | any | 128 | Not stated | [Pack page](https://wiki.alioth.net/index.php/Galactic_Navy_OXP) |
| P14 | Galactic Navy Spec Ops | G6 | 128 | Finished 10 Reserve Sorties | [Pack page](https://wiki.alioth.net/index.php/Galactic_Navy_OXP) |
| P15 | GalCop Missions | any | Not stated | Occasional equipment needs | [Pack page](https://wiki.alioth.net/index.php/GalCop_Missions) |
| P16 | GalCop's Most Wanted | any | Not stated | Various equipment needs | [Pack page](https://wiki.alioth.net/index.php/GalCop%27s_Most_Wanted) |
| P17 | Illegal Goods Tweak | any | any | Released slaves to customs. | [Pack page](https://wiki.alioth.net/index.php/Illegal_Goods_Tweak_OXP) |
| P18 | Ionics | G2 | Not stated | Not stated | [Pack page](https://wiki.alioth.net/index.php/Ionics_OXP) |
| P19 | Iron Raven | G8 | Not stated | Not stated | [Pack page](https://wiki.alioth.net/index.php/Iron_Raven) |
| P20 | Lave Academy | G1 | Not stated | Not stated | [Pack page](https://wiki.alioth.net/index.php/Lave_Academy_OXP) |
| P21 | LinkG7 | G7 | Not stated | Not stated | [Pack page](https://bb.oolite.space/viewtopic.php?f=4&t=9135&hilit=linkg7) |
| P22 | Localhero | G1-G5, government5, tech index>7 | NPC definitions require >50; project gates offer at51 | Bounty<7, fuel scoops;31 assignments | [Source-backed profile](localhero-mission-specifications.md) |
| P23 | Long Way Round / indexed alias Long Way Around | G1 | Not stated | Not stated | [Pack page](https://wiki.alioth.net/index.php/LongWay_OXP) |
| P24 | Lost Worlds Grand Tour | G6 | N/A | GalDrivePod | [Pack page](https://wiki.alioth.net/index.php/GalDrivePod#Lost_Worlds_Grand_Tour) |
| P25 | Love Cats | G4 | No score gate | No native-mission offer prerequisite in 2.0 | [Pack page](https://wiki.alioth.net/index.php/Lovecats.oxp) |
| P26 | Military Fiasco | any | >1000 (1001) | Bounty <5; 2.5.3 and 3.0 differ | [Pack page](https://wiki.alioth.net/index.php/Military_Fiasco) |
| P27 | MincePie | any | Not stated | Mince Pies | [Pack page](https://wiki.alioth.net/index.php/MincePie) |
| P28 | Oo-haul Escort Missions | any | 32 | Good standing with Oo-Haul corp. | [Pack page](https://wiki.alioth.net/index.php/Oo-Haul) |
| P29 | Random Hits | any | 32 | Not stated | [Pack page](https://wiki.alioth.net/index.php/Random_Hits_OXP) |
| P30 | Rescue Stations | any | Escort1: rep>=10, bounty<=50; variants have further gates | All fifteen scenario/variant profiles ready; native implementation separate | [Medical supplies6a](rescue-medical-mission-specifications.md), [Materials transfer6](rescue-materials-mission-specifications.md), [Returning Arafura5a](rescue-returning-mission-specifications.md), [Emergency freighter5](rescue-emergency-mission-specifications.md), [Escort1/1a/1b](rescue-escort-mission-specifications.md), [couriers2/2a](rescue-courier-mission-specifications.md), [solar2b](rescue-solar-mission-specifications.md), [black-box3/3a](rescue-blackbox-mission-specifications.md), [pilot transport4](rescue-personnel-mission-specifications.md), [captured pilot4a](rescue-slaver-mission-specifications.md), [Astromine4b](rescue-astromine-mission-specifications.md), [pack page](https://wiki.alioth.net/index.php/RRS_Group) |
| P31 | Resistance Commander | G5 | 1000 | Ship with at least 6 missile pylons | [Pack page](https://wiki.alioth.net/index.php/Resistance_Commander) |
| P32 | Runner G5 Challenge | G5 | Not stated | Not stated | [Pack page](https://wiki.alioth.net/index.php/Runner_G5_Challenge) |
| P33 | Scourge of the Black Baron | G1 | 151 | Not stated | [Pack page](https://wiki.alioth.net/index.php/Scourge_of_the_Black_Baron) |
| P34 | Shrews Rights | G2 | 512 | Not stated | [Pack page](https://wiki.alioth.net/index.php/Shrews_Rights) |
| P35 | Spy Hunter | G1 | >512 (513) | Not stated | [Pack page](https://wiki.alioth.net/index.php/Spy_Hunter_OXP) |
| P36 | Stealth | G3 | >=512 | Not stated | [Pack page](https://wiki.alioth.net/index.php/Stealth_OXP) |
| P37 | Stellar Serpents | Any | Not stated | Not stated | [Pack page](https://wiki.alioth.net/index.php/Stellar_Serpents_OXP) |
| P38 | Taranis | G1 | >=128 | Bounty <5; dock at Taranis HQ in system 141 (zero-based) | [Pack page](https://wiki.alioth.net/index.php/Taranis_OXP) |
| P39 | Taxi Galactica | Any | Not stated | Not stated | [Pack page](https://wiki.alioth.net/index.php/Taxi_Galactica) |
| P40 | The Collector | G1 | Not stated | Not stated | [Pack page](https://wiki.alioth.net/index.php/TheCollector) |
| P41 | Thargoid Wars | Activation G2-G8 or Plans complete; later G1 possible | No score gate | See 5.0 source activation/reward rules | [Pack page](https://wiki.alioth.net/index.php/Thargoid_Wars) |
| P42 | Tionisla Reporter | G1 | Not stated | Not stated | [Pack page](https://wiki.alioth.net/index.php/Tionisla_Reporter) |
| P43 | To Catch A Thargoid (TCAT) | G3 | 1500 | Finished Thargoid Plans | [Pack page](https://wiki.alioth.net/index.php/TCAT_OXP) |
| P44 | Trident Down | G4 | 512 | Not stated | [Pack page](https://wiki.alioth.net/index.php/Trident_Down) |
| P45 | UPS Courier Company | any | Not stated | Not stated | [Pack page](https://wiki.alioth.net/index.php/UPS_Courier) |
| P46 | Vector | any | 150 | 300 kills for the background story | [Pack page](https://wiki.alioth.net/index.php/Vector_OXP) |
| P47 | Victim 11 | G7 | Not stated | Finished Assassins Guild | [Pack page](https://wiki.alioth.net/index.php/Victim_11) |
| P48 | Xeptatl's Sword | G5 | Not stated | None | [Pack page](https://wiki.alioth.net/index.php/Xeptatl%27s_Sword) |

These are pack-level records. Their individual sub-missions and end conditions are not supplied by the index. Localhero, Vector and Xeptatl's Sword have explicit compatibility/deprecation warnings in O06.

## Expansion profiles added after the discovery index

P01 now has a separate [Assassins Guild Rebooted specification](assassins-mission-specifications.md). P01-A01 through P01-A10 identify its ten contracts; retained revenge/news/flight states remain attached to that campaign; the on-foot adventure is excluded rather than becoming duplicates of the same assassination. P48 Xeptatl's Sword3.0 now has a [source specification](xeptatl-mission-specifications.md) for both circuits, component retrieval, Hive and finale branches, with50 source fixtures. Source defects and encounter runtime remain explicit; original2.3 parity is not assumed.

P39 Taxi Galactica2.2 now has a [ship-passenger specification](taxi-mission-specifications.md): one generated G05 profile plus the distinct Ambassador assignment, with28 callback checks and native engine payment/expiry rules.

## Additional recovered expansion profiles

P02 [Aquatics](aquatics-mission-specifications.md), P08 [Black Sunspot](black-sunspot-mission-specifications.md), P10 [Escort Contracts](escort-mission-specifications.md), P17 [Illegal Goods Tweak](illegal-goods-mission-specifications.md), P20 [Lave Academy](academy-mission-specifications.md) and P34 [Shrews' Rights](shrews-mission-specifications.md) now have analysed core rules. Their stage/service/training variants remain nested under their canonical pack IDs. See each profile for station handoffs, source quirks and runtime validation limits.

Dedicated analysed profiles: [P11 Feudal States](feudal-mission-specifications.md), [P12 Galactic Almanac](almanac-mission-specifications.md) and [P31 Resistance Commander](resistance-mission-specifications.md). Their sub-mission families retain these canonical pack identities; ENVOY is unfinished reference code. P13/P14 have a [recovered modified Navy specification](navy-mission-specifications.md):four reserve battle variants and the complete Kurtz capture/killed/escaped graph, with source/archive provenance.

[P43 To Catch a Thargoid](to-catch-thargoid-mission-specifications.md) now has a dedicated source/profile analysis and31 selected callback checks. [Mechanics appendix](data/tcat-mechanics.json) records32 AI state tables and18 numeric equipment definitions. Bomb placement becomes an automated central-station handoff, with verified10second escape countdown; source narrative30seconds and ship-switch cancellation are not silently carried into the repaired player profile.

[P06 Cataclysm](cataclysm-mission-specifications.md) establishes the main A/B route, four wartime side families and post-campaign hive contracts. Source gate5120corrects the older discovery index. [P16/P22/P46 archives](data/legacy-source-recovery.json) are recovered; P46 remains an analysis gap, while P22 has a [complete31-assignment profile](localhero-mission-specifications.md) and P16 an [11-archetype bounty generator](most-wanted-mission-specifications.md).

Additional recovered profiles: [P05 Blackjack](blackjack-mission-specifications.md), [P28 Oo-Haul](oohaul-mission-specifications.md), [P32 RunnerG5](runner-g5-specifications.md), [P47 Victim11](victim11-mission-specifications.md), with25 selected source callbacks and [466 legacy resource definitions](data/legacy-expansion-resources.json). P24 is corrected to the author-described [Grand Tour activity](grand-tour-specifications.md), with five tour/challenge endpoint bindings independently matched between recovered C and project Swift. New numeric project choices and repaired callbacks remain labelled; original narrative/graphics are not copied.

[P21 LinkG7](linkg7-mission-specifications.md) is now recovered and analysed. Public folder inventory identifies file631078585, LinkG7v0.1.zip,6768bytes; all eight textual member hashes are in [legacy recovery](data/legacy-source-recovery.json). [16 source callbacks](data/linkg7-source-fixtures.json) and [eight independently matched route endpoints](data/linkg7-route-bindings.json) establish the trial, while prototype installation, missing reoffer, wrong-galaxy progression, outbound midpoint range and unbounded retry defects have explicit project repairs.

[P44 Trident Down](trident-down-specifications.md) now has the four-way investigation/political campaign, nine advertised story endings plus initial rejection, station handoffs and explicit missing failure-path repairs. [40 selected callbacks](data/trident-source-fixtures.json), [complete explicit stage/effect graph](data/trident-source-graph.json), [resolved119 definitions/27 AIs/22 route bindings](data/trident-mechanics.json) and [three recovered dependency revisions](data/trident-dependency-sources.json) retain inspectable provenance. All12 previous P44 parent gaps are resolved; source tier/equipment values remain distinct from eventual player refits.

[P46 Benus escort and Arn prototype](vector-arn-mission-specifications.md) are individually ready with 35 selected callback checks, explicit orbital boarding/medical/sabotage replacements, finite reachable route generation, unique reward/storage and gallery contracts. This bounded packet does not close the other Vector salvage/inspection/Areidis/specialist families.

[P46 Richmans World and flight inspection](vector-salvage-inspection-specifications.md) are now individually ready and delivered: six settlement choices, exact quote/risk/strength rules, scanner approach/compliance/fines, explicit once-only payment and safe custody repairs, 78 selected source callbacks and 20 CCL callbacks. [Shared Vector mechanics](data/vector-services-mechanics.json) pin 87 definitions, 21 AIs, 24 base envelopes and 36 station flag rows; aliases/components are not additional hulls. Original NPC energy inputs require the explicitly borrowed O08 booster/enhancer assembly; native implementation remains separate. Areidis/Specialist station closure is still pending.

[P46 Areidis terminals and Specialist trade](vector-station-specifications.md) complete the recovered Vector objective inventory: 24 scripts accounted for across six retained bounded mission/event families, 17 selected station checks, five identical decrypted messages with no invented continuation, seven independently matched endpoints, source gram-unit market rules and explicit orbital/animation/custody/reward repairs. Missing scanner unlocks, empty/future phone/actor handlers and original walking/cubes remain reference-only. All six profiles have been delivered incrementally with gallery requirements; original-engine parity and native implementation remain separate.

P19 bounded follow-up14October2026: the [Kinnaird investigation and shared follow-up choice](iron-raven-kinnaird-specifications.md) is now individually research-ready after all four investigation strands. Its actual Atanon/Orlaaror/Laxesori/Vegedius station sequence and two preceding campaign dismissals have full source/repair/custody/save/Gallery parameters. Hotel/club evidence becomes an orbital security record. This is a completed branch specification within existing P19, not a new canonical inventory row or proof of native implementation. Weiss/LEXICON/later branches, parent activation and finales remain open.

P19 Weiss surveillance is now independently specified and delivered: [complete two-jump orbital profile](iron-raven-weiss-specifications.md) with actual QC272 transit/docking, preserved SH128crew/passenger/condition, station-record replacement,0newpayment/save/failure/parent/Gallery contract. Kinnaird and Weiss are separate exclusive parent continuations, not duplicate photo missions or new canonical campaign rows. Both share the later20day lead without establishing LEXICON/Cherkasova/finale readiness or native implementation.

P19LEXICON capture is now [individually complete and delivered](iron-raven-lexicon-specifications.md): strict intelligence wait, orbital coordination, finite17rootspace encounter, real liveWeiss capsule capture and Laxesori handoff. Its source ground briefing/planet-bound AI are explicitly replaced by orbital services/flight; capturedperson care/one protectedtonne/nochartercabin, honestKinnaird outcomes,0missionpay/save/failure/Gallery are complete. This is the third exclusive continuation within existingP19, not a duplicate campaign/newcanonical row or proof of native playability.
