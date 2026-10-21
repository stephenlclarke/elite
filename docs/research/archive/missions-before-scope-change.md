# Archived: missions.md before mission scope change

**Excluded reference snapshot. Do not implement removed mission content from this document. The active [scope](../implementation-scope.md) takes precedence.**

## Deduplicated mission catalogue

Version IDs are defined in [versions](../versions.md). An appearance lists a supported edition, not every presumed derivative. Readiness levels R1/R2/R3/U are defined in [coverage](../coverage.md). Canonical story missions link to the [main specification](../mission-specifications.md) or the detailed port supplements below. Readiness is specific to the inspected profile, not every edition in a row. Sources identify the relevant original reference in [sources](../sources.md).

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

BBC-TAPE and ELECTRON have no scripted story missions. A cloaked ship in BBC-MASTER is not a separate C05 assignment. ARC's campaign replaces the naval missions rather than proving their presence. The identified ZX128 scheduler and selected outcomes are now confirmed in S42; complete mission paths remain R2. EINSTEIN, PC98, PLUS4 and other TNK derivatives require separate confirmation. ELITE-A's special deliveries are G04; inherited naval scripts remain unverified here. [S01, S08, S10](../sources.md)

## Oric 1337 unique assignments and tutorials

All entries below are ORIC1337, source S38, R1 core graph / R2 disk and engine parity. Full prerequisites, destinations, cargo quantities, encounter positions, branches, rewards and state bytes are in the [Oric specification](../oric-mission-specifications.md). C01 and C02 retain their existing IDs instead of being duplicated here. Names below are descriptive labels based on the mission code, not asserted official menu titles.

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

## First Encounters story assignments

All F entries are FFE only; DOS patches and JJFFE can alter observed bugs. These are distinct narrative assignments even where they share a generated-contract mechanic. [S14, S15, S16, S39, S43, S44](../sources.md). The [journal and save profiles](ffe-journal-and-save-profiles.md) adds dates, journal operations and six checked start states. The [source supplement](first-encounters-source-notes.md) adds verified interpreter predicates; raw undecided opcodes remain explicit.

| ID | Canonical mission | Readiness |
| --- | --- | --- |
| F01 | Wiccan Ware Race | R2 |
| F02 | Soholia Medicine Relief / Disease at Soholia | R2 |
| F03 | Transport Duval Artefact / Art delivery to Beta Hydri | R2 |
| F04 | Assassinate Dentara Rast | R2 |
| F05 | Assassinate Dr Joreb Innitu | R2 |
| F06 | The Two Hitchhikers | R2 |
| F07 | Assassinate the Assassin of Dentara Rast | R2 |
| F08 | The Visitor to Thompson's Planet | R2 |
| F09 | Destroy Rockforth Legal Academy | R2 |
| F10 | Deliver Junior's Friend | R1 source core / R2 runtime |
| F11 | Transport the Five Furies | R1 source core / R2 runtime |
| F12 | Rescue Stranded Hitchhiker / Jan Thikka | R1 source core / R2 runtime |
| F13 | Argent's Quest first expedition | R2 |
| F14 | Red Square Flowers | R2 |
| F15 | Argent's Quest second expedition | R2 |
| F16 | Thargoids' Mycoid Mission / vaccine retrieval | R2 |

## First Encounters unfinished branches

| ID | Surviving mission identity | Versions | Readiness | Source |
| --- | --- | --- | --- | --- |
| U01 | Jo Merion's Message | FFE surviving text | U | S17 |
| U02 | INRA Delivery first offer | FFE surviving text | U | S17 |
| U03 | INRA Delivery second offer | FFE surviving text | U | S17 |
| U04 | Hunt the Vaccine | FFE surviving text | U | S17 |
| U05 | A Change of Identity | FFE surviving text | U | S17 |

U01 is not the playable F14 or the separate information-for-sale advert. S17 reports these as unfinished. The newly recovered JJFFE graph has not yet established reachability and full outcomes for every related branch; surviving text alone is insufficient for either a playable or absent claim.

## Elite Dangerous named assignments

| ID | Mission or scenario | Versions | Readiness | Sources |
| --- | --- | --- | --- | --- |
| D01 | Decoding the Ancient Ruins | ED-LIVE; historical Horizons-era availability | R2; complete 101-log table | D01, D16, D18 |
| D02 | Decrypting the Guardian Logs | ED-LIVE; historical Horizons-era availability | R2; complete 28-log table | D02, D17, D18 |
| D03 | Terminal Prosecution | ED-ODYSSEY Operations | R2 sequence / R3 exact parity | D05, D19, D20 |
| D04 | Tactical Takedown | ED-ODYSSEY Operations | R2 sequence / R3 exact parity | D05, D19, D20 |
| D05 | Firestorm Rescue | ED-ODYSSEY Operations | R2 sequence / R3 exact parity | D05, D19, D20 |
| D06 | Rapid Response | ED-ODYSSEY Operations | R2 sequence / R3 exact parity | D05, D19, D20 |
| D07 | Reclamation Point | ED-ODYSSEY Operations | R2 sequence / R3 exact parity | D05, D19, D20 |
| D08 | Biohazard Takedown | ED-ODYSSEY Operations | R2 sequence / R3 exact parity | D05, D19, D20 |
| D09 | Under Siege | ED-ODYSSEY Operations | R3 | D05, D21 |

Source D01 and mission D01 are different namespaces. Use `source:D01` and `mission:D01` when exporting records. Historical Guardian assignments are not asserted to retain identical present-day rewards on ED-LEGACY.

## Generated objective families

These are reusable mechanics, not additional copies of each story mission. FE2 has a generated mission system rather than FFE's dated campaign. Sources: [S10, S16, S18, D03, D04](../sources.md).

| ID | Objective family | Versions supported by the references |
| --- | --- | --- |
| G01 | Information and missing-person enquiries | FE2, FFE |
| G02 | Data or package courier | FE2, FFE, ED-LIVE, ED-LEGACY, OOLITE |
| G03 | Supplied freight delivery or commodity procurement | ED-LIVE, ED-LEGACY; OOLITE freight contracts |
| G04 | Special cargo with docking-dependent payment | ELITE-A |
| G05 | Passenger transport | FE2, FFE, ED-LIVE, ED-LEGACY, OOLITE |
| G06 | VIP sightseeing or expedition | ED-LIVE, ED-LEGACY |
| G07 | Assassination of a named ship or person | FE2, FFE, ED-LIVE, ED-LEGACY; ED-ODYSSEY on foot |
| G08 | Massacre or target-count combat | ED-LIVE, ED-LEGACY; ED-ODYSSEY on foot |
| G09 | Photo reconnaissance | FE2, FFE |
| G10 | Military bombing | FE2, FFE |
| G11 | Classified reconnaissance involving defence satellites | FFE |
| G12 | Theft or liberation of cargo and hostages | ED-LIVE, ED-LEGACY |
| G13 | Salvage and recovery | ED-LIVE, ED-LEGACY; ED-ODYSSEY surface items |
| G14 | Data scanning or download | ED-LIVE, ED-LEGACY; ED-ODYSSEY terminals |
| G15 | Upload or digital infiltration | ED-ODYSSEY |
| G16 | Generator or process sabotage | ED-LIVE, ED-LEGACY; ED-ODYSSEY |
| G17 | Item theft or secure-container heist | ED-ODYSSEY |
| G18 | Settlement power restoration and fire suppression | ED-ODYSSEY |
| G19 | Settlement raid, scavenger clearance or defence | ED-ODYSSEY |
| G20 | Mining and delivery | ED-LIVE, ED-LEGACY |
| G21 | Credit or commodity donation | ED-LIVE, ED-LEGACY |
| G22 | Passenger evacuation and survivor rescue | ED-LIVE, ED-LEGACY; event availability differs |
| G23 | Tip-off investigation | ED-LIVE, ED-LEGACY |
| G24 | Designated anti-xeno combat | ED-LIVE; historical ED-LEGACY availability differs |

Smuggling is a legality condition on cargo; covert and nonviolent are objective constraints; team/wing and chained contracts describe participation and sequencing. Keep those attributes rather than duplicate every combination. Free exploration, trading and bounty hunting are not automatically contracts.

## Oolite optional campaigns

All P entries are OOLITE-OXP. P03, P04, P09, P18, P23, P25, P27, P33, P35, P36, P37, P38, P41 and P42 have analysed core graphs in the [expansion specification](../oolite-expansion-specifications.md); Ionics battle compatibility remains R2. P26 has a historical 2.5.3 graph and a distinct 3.0 spawn blocker. P40 has a documented published portion ending at an unfinished continuation notice. Other entries remain R3 discovery records. [O06, O07](../sources.md). Availability and mechanics depend on installed package versions.

| ID | Pack or campaign | Indexed galaxy | Indexed kills | Other prerequisites | Detail source |
| --- | --- | --- | --- | --- | --- |
| P01 | Assassins Guild | G7 | 200 | Not stated | [Pack page](https://wiki.alioth.net/index.php/The_Assassins_Guild_OXP) |
| P02 | Aquatics - The Kraken IV | G3 | Not stated | Good standing with the Corporation | [Pack page](https://wiki.alioth.net/index.php/Aquatics_OXP) |
| P03 | Asteroid Storm | G1 | 64 | Not stated | [Pack page](https://wiki.alioth.net/index.php/Asteroid_Storm) |
| P04 | Bank of the Black Monks | any | Not stated | Not stated | [Pack page](https://wiki.alioth.net/index.php/Black_Monk_Monastery) |
| P05 | Blackjack's Bullion | G2 | Not stated | Not stated | [Pack page](https://wiki.alioth.net/index.php/BlackjacksBullion_OXP) |
| P06 | Cataclysm | G1 | 5200 | Finished Thargoid Plans | [Pack page](https://wiki.alioth.net/index.php/Cataclysm_OXP) |
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
| P22 | Localhero | G1-G5 | 50 | Must be lawful | [Pack page](https://wiki.alioth.net/index.php/Localhero_OXP) |
| P23 | Long Way Round / indexed alias Long Way Around | G1 | Not stated | Not stated | [Pack page](https://wiki.alioth.net/index.php/LongWay_OXP) |
| P24 | Lost Worlds Grand Tour | G6 | N/A | GalDrivePod | [Pack page](https://wiki.alioth.net/index.php/GalDrivePod#Lost_Worlds_Grand_Tour) |
| P25 | Love Cats | G4 | No score gate | No native-mission offer prerequisite in 2.0 | [Pack page](https://wiki.alioth.net/index.php/Lovecats.oxp) |
| P26 | Military Fiasco | any | >1000 (1001) | Bounty <5; 2.5.3 and 3.0 differ | [Pack page](https://wiki.alioth.net/index.php/Military_Fiasco) |
| P27 | MincePie | any | Not stated | Mince Pies | [Pack page](https://wiki.alioth.net/index.php/MincePie) |
| P28 | Oo-haul Escort Missions | any | 32 | Good standing with Oo-Haul corp. | [Pack page](https://wiki.alioth.net/index.php/Oo-Haul) |
| P29 | Random Hits | any | 32 | Not stated | [Pack page](https://wiki.alioth.net/index.php/Random_Hits_OXP) |
| P30 | Rescue Stations | any | Not stated | Not stated | [Pack page](https://wiki.alioth.net/index.php/RRS_Group) |
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

P01 now has a separate [Assassins Guild Rebooted specification](../assassins-mission-specifications.md). P01-A01 through P01-A10 identify its ten contracts; revenge/news/adventure states remain attached to that campaign rather than becoming duplicates of the same assassination. P48 Xeptatl's Sword3.0 now has a [source specification](../xeptatl-mission-specifications.md) for both circuits, component retrieval, Hive and finale branches, with50 source fixtures. Source defects and encounter runtime remain explicit; original2.3 parity is not assumed.
