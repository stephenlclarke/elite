# Oric 1337 campaign and tutorials

Source S38 is Chema Enguita's mission code in the Oric Software archive, pinned to commit `c81612082482d1f497638ada14ad4640c5e4f1ec`. Inspect `users/chema/1337/TINE/missions.s`, `missions/mission0.s` through `mission11.s`, `missions/tutorial0.s` through `tutorial3.s`, plus the event calls in `tineloop.s`, `universe.s` and loader in `tail.s`. This establishes the shipped-source campaign graph; it does not establish a hash match to every distributed disk image. The main [catalogue](missions.md) assigns R01-R10 to unique Oric story assignments, T01-T04 to tutorials and reuses C01 for Constrictor and C02 for plans delivery.

## Conventions and runtime

Oric uses galaxy numbers 1-8 directly. Planet numbers below are the source's 0-255 generated indices. Cash uses tenths of a credit. Score is a two-byte value, distinct from its fractional remainder. Object coordinates are the script's signed integer coordinates; retain Oric's forward-axis convention rather than assuming positive z is in front.

Mission state is a byte divided into four-state file blocks. `missions.s` overrides NEXTMISSION for branching; file number alone is not a valid next-state calculation. `0xFC` ends the entire campaign as failed; `0xF8` ends it successfully. `tail.s` handles both before the ordinary NeedsDiskLoad test, clears mission event vectors and resets encounter suppression/mission cargo. A failure need not set NeedsDiskLoad to terminate the pack.

Events are player launch, docking, hyperspace, system entry, ship destruction/docking/hyperspace, encounter generation, scoop and game load. Returning carry set normally requests a briefing; for scoop it means the mission already handled the object and ordinary cargo handling must be skipped. Normal system creation invokes the mission entry event before three ordinary encounter attempts, making AvoidOtherShips relevant immediately.

Maintain each file's local target object IDs, success/failure flags, remaining asteroid count and suppression flags. These locals are not equivalent to the global saved mission byte. Original flight encounters and fresh reloads must be tested separately: a modern save-anywhere system must either preserve locals or explicitly emulate the original restart behaviour. Do not claim that saving only the mission byte faithfully resumes an active battle.

## Campaign graph

Normal play begins at state 0. The tutorial is an alternate entry beginning at state 13 and eventually returns to state 0. Trade jobs use ordinary cargo slots, so buying, selling or losing the required goods affects completion according to the quantity predicate. They do not track a unique sealed consignment.

| ID | Source file / base | Offer, stages and completion | Failure, reward and next state |
| --- | --- | --- | --- |
| R01 | mission0 / 0 | Launch with score >=18 ->1, Milto Zaxx invitation. Dock Rilace G1/222 ->2. Launch there with >=10 free hold loads 10 food ->3. Dock Usrarema G1/146 with >=10 food to deliver. Insufficient hold leaves the pickup pending. | Insufficient delivery quantity ->0xFC. Remove 10 food, add 200 credits, next 4. |
| R02 | mission1 / 4 | Launch with score >=22 ->5. Dock Xexedi G1/250 ->6; launch there with sufficient hold to load 15 food ->7. Deliver at Teen G1/209, or use legal diversion at Usatqura G1/109. | Teen removes 15 food, pays 500 credits, next 8. Diversion removes 15 food, pays 300 credits, clears legal status and jumps to 28, bypassing R03. Teen shortage fails the campaign; diversion shortage leaves it pending. |
| R03 | mission2 / 8 | Launch with score >=26. At Teraed G1/99 load five narcotics (cargo index 6); deliver to Xeenle G1/213. | Remove five narcotics, pay 500 credits, next 28. Insufficient cargo follows the file's campaign-failure branch. |
| R04 | mission3 / 28 | Launch with a galactic drive (`_equip & 0x80`) or score >=80. At Zadies G1/131 load 15 machinery (index 8); deliver to Beveri G2/181. | Pay 1,000 credits and install the fuel-processor mission equipment, next 32. Retain the exact equipment flag rather than substituting ordinary scoops. |
| R05 | mission4 / 32 | On player launch or hyperspace in G2, RNG byte <80 starts rescue. Entry ->33 creates Maynard Zantor's Cobra and three attacking Mambas. | Cobra docking sets success; its destruction sets failure. At player docking or hyperspace while 33 evaluate these flags. Leaving before rescue or after target loss ->0xFC. Success ->36, no explicit cash. |
| R06 | mission5 / 36 | Launch or hyperspace in G2 with RNG byte <80 ->37, suppress ordinary ships. Next entry creates two hostile Mambas ->38 and restores encounters. Dock anywhere ->39, Untha Banhath message. Dock Resori G2/189 for the follow-up. | No kill quota. Resori meeting advances to 41, directing player to Riave G3. No explicit cash. |
| R07 | mission6 / 40 | Entry at Riave G3/0 while state 41 ->42; dock there for Garmond Hasler's briefing. | Next 45, fetch a container from Rebees. No explicit reward or timeout. |
| R08 | mission7 / 44 | Enter Rebees G3/8 in state 45 ->46; spawn a cloaked container, two asteroids and cloaked Cougar. Scoop the matching container ID ->47 and consume scoop event. Return Riave G3/0. | Docking while 46 ->0xFC. Docking elsewhere in 47 does not finish. Riave in 47 ->48. No explicit cash; destruction of container has no separate recovery/failure handler in this file. |
| R09 | mission8 / 48 | Any system entry in 48 with RNG byte <40 ->49, summons to Edorqu G4/10. Correct entry ->50: defend against eight mission asteroids. | Any impact on planet marks failure and blocks further successful count progression. Leaving/docking in 50 fails; last required kill ->51, then docking or hyperspace succeeds ->53. No explicit cash. |
| C02 | mission9 / 52 | Dock Rianxe G4/154 for Admiral Curruthers' debrief. During this file's encounter hook, random byte >=200 can add an ECM-equipped Thargoid. | Next 56. No checked cargo quantity or explicit countdown despite the narrative urgency. |
| C01 | mission10 / 56 | Dock in G4, except Aingeon/114, with RNG byte <50 ->57; follow Constrictor trail to G5/111. Matching target destruction in battle state 58 ->59. | Completion handler at player docking or the next encounter callback in 59 grants +16 score and extra fuel-optimizer equipment, next 60. No explicit cash. |
| R10 | mission11 / 60 | Enter Gelesoma G7/79 ->61, suppress ordinary encounters, create Torjan Mino's Mamba with two Kraits. Destroy Torjan ->62. | Player docking or hyperspace while 61 ->0xFC. In 62: restore encounters, add 10,000 credits and 0x0500 (1,280) score, next 0xF8. Escort kills alone do not satisfy the target-ID check. |

Probability statements describe a byte comparison, not guaranteed independent uniform samples. Use the Oric RNG and the original event call order for deterministic parity. Ordinary ship destruction scoring and bounties are additional to mission-script rewards.

## Encounter parameters

| Assignment | Objects and script properties |
| --- | --- |
| R05 | Cobra Mk I at (0,0,-2000), innocent, fly-to-planet, bold/defenceless, target 2. Mambas at (4500,0,-8000), (-4500,0,-8000), (-4500,-4500,-7000), target the Cobra, no missiles. Bind success to the Cobra's docking callback, not the player killing all pirates. |
| R06 | Mambas at (0,-4500,0) and (4500,0,0), bold pirates, angry at player, one missile each. No mandatory destruction predicate before the subsequent docked conversation. |
| R08 | Container at (-4000,-4000,-4600), cloaked. Asteroids at (-4000,-4000,-4000) and (4000,-4000,-4000). Cougar at (-4000,5000,-6000), cloaked, pirate and angry at player. Scoop requires that spawned container's object ID. |
| R09 | Three initial asteroids at (-4000,-4000,-9000), (4000,-4000,-9000), (4000,4000,-9000); five reserve bodies, eight total. Fly to planet/defenceless, target 2, z rotation 3. Each mission-asteroid destruction decrements the outstanding total; while reserves remain select one of four fixed positions using `IndRnd &3`: (-4000,-4000,-9000), (4000,-4000,-9000), (4000,4000,-9000), (-4000,4000,-9000). Only matching mission asteroids count. |
| C02 | Extra Thargoid at one of the same four fixed positions used by R09, selected by a second `IndRnd &3` call; ECM, one or two missiles (`(IndRnd &1)+1`), hostile to player. The trigger is `randomByte >=200`, 56/256 possible byte values. |
| C01 | Constrictor at (-4000,4000,-4000), ECM, military resistance, hard/bold pirate, two missiles. Its entry handler tests G5/system 111 without an explicit mission-57 guard, then increments the state. Preserve this source edge case separately from an adapted one-spawn-only profile. |
| R10 | Torjan Mamba at (0,0,-2000), two Kraits at (4500,0,-8000) and (-4500,0,-8000), hostile to player. Only Torjan's recorded object ID advances 61->62. |

### Inherited resource profile

The [33-entry ship resource table](data/oric-ship-resources.json) supplies every `ships.s` energy, maximum speed, size, ammo, cargo, score and bounty entry. It is evaluated with this source's active `SCALED` and `EX_DAM=3` options, using type ID minus one for table indexing. The size and speed values are raw engine fields, not metres and metres per second. `AddSpaceObject` initializes energy and ammo from these tables but sets current speed, acceleration, rotations, target, flags, TTL and AI state to zero; mission setup then overrides selected fields. `SetShipEquip` replaces the entire equipment byte. It does not OR the supplied bits into an existing value.

| Mission object | Type | Energy | Max speed, raw | Default laser damage | Default missiles | Kill score, 256ths | Bounty, tenths |
| --- | --- | --- | --- | --- | --- | --- | --- |
| CARGO | 5 | 8 | 20 | 0 | 0 | 112 | 1 |
| ASTEROID | 7 | 56 | 30 | 0 | 0 | 110 | 15 |
| SPLINTER | 8 | 16 | 10 | 0 | 0 | 112 | 1 |
| COBRA1 | 17 | 81 | 26 | 7 | 2 | 315 | 75 |
| KRAIT | 19 | 73 | 30 | 7 | 0 | 315 | 100 |
| MAMBA | 20 | 80 | 30 | 7 | 2 | 358 | 150 |
| ADDER | 22 | 72 | 24 | 7 | 1 | 320 | 40 |
| THARGOID | 29 | 253 | 39 | 12 | 0 | 912 | 500 |
| CONSTRICTOR | 31 | 255 | 36 | 13 | 7 | 1595 | 0 |
| COUGAR | 32 | 115 | 40 | 11 | 7 | 1595 | 0 |

Mission missile changes preserve the upper five laser bits. NPC laser hit damage is the ammo byte shifted right three, established in `tactics.s`; the default table therefore already includes EX_DAM. Ordinary kill scoring adds a 16-bit table value to the fractional remainder and score, rather than always awarding one point. Innocent/defenceless legal consequences and ordinary bounties remain additional to mission-script rewards.

### Mission randomness, impact and allocation

`tail.s:IndRnd` dispatches to `randgen` when `REALRANDOM` is defined, as it is in `tine.h`. This is a VIA-timer-dependent generator, not the four-byte `_gen_rnd_number` used for planet descriptions and some ordinary cargo. For exact reproduction capture the timer reads, incoming carry and interrupt order in addition to the two-byte seed, initially 0xDEAD. `randgen` saves flags, enables interrupts, ORs the low seed with VIA address 0x0308, rotates through carry, adds VIA 0x0304 with carry, stores the low byte, subtracts the old high byte with borrow, rotates and stores the high byte, then restores the caller's flags. Its returned A is the new high byte. A seed alone is insufficient to replay these mission byte comparisons.

The R09 and C02 positions are four discrete coordinates; there is no missing continuous random-coordinate routine for these spawns. R09 clears a destroyed target's ID and decrements its outstanding count before trying to allocate a replacement. If `AddSpaceObject` returns X=0, the reserve count is not consumed, but the cleared slot has no active asteroid to trigger its next replacement. This can strand a defence sequence; preserve an object-pool-exhaustion fixture instead of inventing a retry timer.

The fly-to-planet docking/impact decision in `tactics.s` is an axis/high-byte test, not a spherical impact radius. The approach branch requires the absolute signed z high byte to be <5 and `(abs(xHigh) | abs(yHigh)) &0xFE ==0`; it then sets `IS_DOCKING` for `FLG_FLY_TO_PLANET` objects. The high-byte absolute operations are byte arithmetic and must be reproduced as written at negative-coordinate boundaries. The mission's ship-docked callback turns a matching asteroid into a failure. Full steering, transform precision and simulation cadence still require engine parity.

## Oric C01 clue route

G4: Aingeon/114 -> Mavelege/13 -> Veteerza/29 -> galaxy 5. G5: Intedi/29 -> Rainte/18 -> Veedri/186 -> Rabeer/222 -> Beatza/183 -> target system 111. The clue handler treats every galaxy other than G4 as its alternate table; other systems can give the general clue with random byte <20. Clues guide navigation; there is no checked requirement to visit each clue in order before the target-entry branch. Do not transplant Orarra or the BBC reward into this campaign.

## Tutorials

| ID | Source / base | Objective and transitions | Important source limits |
| --- | --- | --- | --- |
| T01 | tutorial0 / 12 | Launch from Lave G1/7 while state 13 ->14; dock at Lave ->16. Learn flight, compass and landing. | Dock handler checks galaxy/planet but does not check all preceding flight actions or a manoeuvre score. Encounters suppressed. |
| T02 | tutorial1 / 16 | Launch Lave from base state ->17, spawn six splinters. Destroy six, dock Lave ->20. Early docking resets to 16 for retry. | Counter counts SHIP_SPLINTER destruction, not six individually bound target IDs. Positions: (0,0,-2000), (-2000,0,-2000), (2000,0,-2000), (-2000,0,-1000), (2000,0,-1000), (0,0,0). Encounters suppressed. |
| T03 | tutorial2 / 20 | Launch Lave ->21; destroy the spawned Adder ->22; dock Lave ->24. Early docking resets to 20. | Adder at (0,0,-2000), bold pirate, angry at player, no missiles. Completion binds its object ID. Encounters suppressed. |
| T04 | tutorial3 / 24 | Launch Lave ->25; enter Zaonce G1/129 for navigation instructions; dock Zaonce while 25 ->0, normal campaign. | Food purchase/sale and refuelling are teaching instructions, not checked success conditions. Normal encounters enabled. No explicit cash or score reward in any tutorial. |

## Fidelity checks and outstanding evidence

Core mission logic is R1 for the inspected source; exact disk-release parity and encounter resources remain R2. Required scenarios: each score boundary; full/insufficient cargo; ordinary replacement goods; legal diversion skipping R03; galactic-drive OR score gate; leaving rescue early; Cobra destroyed versus docked; R06 docking without kills; wrong canister; lost canister; each of eight R09 kills and a planet impact; Constrictor premature entry and revisits; escort-only Torjan kills; tutorial retry; tutorial T04 completion without food; and save/load at every mission-file change.

Remaining verification must establish the distributed disk/overlay hashes, compile-time mission options, hardware-timer/interrupt traces, active battle reload behaviour and event-order edge cases. Ship tables and the four fixed spawn positions are now supplied; steering and original timing still require runtime parity. These are specific parity requirements; the source now supplies the campaign inventory and primary objective graph rather than only the game's title.
