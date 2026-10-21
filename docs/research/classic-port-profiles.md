# Classic mission profiles recovered from source

This supplement corrects gaps in C01-C06 and C08. Read it with the [main specification](mission-specifications.md) and [sources](sources.md). Source revisions identify inspected code, not a verified match to every retail executable. Do not transfer rules between ports merely because the mission name matches. All indices below are zero-based except Oric galaxies, which are one-based in its own code.

## C64 and NES: C03 Trumbles

Evidence: S34 and S35, `DOENTRY`, `TBRIEF`, `SOLAR`, `Main game loop (Part 5 of 6)`, heat handling and escape-pod routines. S06's simplified prose is superseded by these instructions where they disagree.

### Offer and payment

C64 tests `CASH+2 >= 0xC4` and TP bit 4 clear. CASH is a four-byte big-endian integer in tenths of a credit. This is a check of one byte, not a monotonic comparison of the whole cash balance. At balances below 6,553.6 credits, the qualifying interval is 5,017.6-6,553.5 credits. At 6,553.6 the tested byte wraps to zero; the same byte pattern recurs in later 6,553.6-credit windows. Implement the byte predicate for source parity, not `cash >= 5017.6` or `cash >= 6553.6`.

NES instead ORs the two high cash bytes, so its qualifying balance is at least 6,553.6 credits. Both mark the offer as seen before the player's answer, charge 50,000 internal cash units (5,000 credits) on acceptance and seed one creature. Declining consumes the original offer. The C64 source comment describing a 50,000-credit price is inconsistent with the executable arithmetic.

### Population algorithm

Keep population as a two-byte unsigned register pair, low byte L and high byte H. At system setup, the routine tests L alone. If L is zero, both breeding and mission-related cargo consumption are skipped, even when H is nonzero. Otherwise C64 clears all food and narcotics; NES clears food only.

For jump breeding, use the selected port's DORND RNG, retaining its returned carry C. Let `s = L + (randomByte & 15) + C`. Set carry to the overflow of s, then set A to `(s & 255) | 4`. Rotate A left through that carry, recording A's old bit 7 as the next carry; store A as L. Rotate H left through that next carry. If H is now negative as a signed byte, rotate H right once through its outgoing carry. This register sequence is materially different from the prose approximation "add a random 4-15 and double". DORND is carry-sensitive on entry; port-accurate RNG fixtures must preserve that input as well as the four seed bytes.

During the main-loop breeding check, H must be nonzero. A random byte >=220 supplies carry to an increment of the register pair, nominally 36/256 checks when outputs are uniform. If H overflows to 0x80, decrement H to 0x7F. At population 0x7FFF this produces 0x7F00; it is not a saturating clamp to 32,767. The cadence is the original loop cadence, including its docked/view behaviour, not one tick per modern rendered frame.

At cabin heat >=240, halve the register pair with unsigned shift-right. This happens in the heat update, before the fuel-scoop equipment check, so scoops are not required to kill creatures. Heat >=224 enables fuel-scoop consideration; that lower threshold does not kill Trumbles. Temperature overflow kills the ship. An escape pod with a nonzero population retains `(randomByte & 7) | 1` survivors: exactly 1, 3, 5 or 7, not every integer from one through seven. Clear the high byte.

### Trumble fixtures

Check cash at 5,017.5; 5,017.6; 6,553.5; 6,553.6; and the next qualifying byte window. Check refusal, one-time purchase, population 0x0100 at a jump, overflow at 0x7FFF, heat 239 versus 240, heat without scoops, and all four escape-pod survivor outcomes. Exact visual sprite selection and sound cadence are presentation work, not new mission identities.

## C64: C01 reward timing correction

The C64 `KILLSHP` Constrictor branch sets TP bit 1 and adds 256 combat points on target removal. Its `DEBRIEF` deliberately comments out a second 256-point increment and adds 50,000 cash units. Thus do not move the 256-point bonus to docking or pay it twice. The ordinary destruction-scoring path is separate from this special increment. BBC variants must be checked independently before reusing the same timing. [S34]

## Atari ST original-source profile

Evidence: S36, `src_orig/asm/missions.m68`, `flight.m68`, `galaxy.m68`, `orbit.m68`, `main.m68`, `combat.m68`, `logic.m68`, `vector.m68`, `radar.m68`, `objects.dat` and `disk.m68`. This is the converted original-source directory in an enhancement repository. Enhanced `src_atari` and `src_amiga` are separate profiles. Original headers identify an ST lineage with later amendments; retail and Amiga binary equivalence is not established.

### Scheduler and saved data

The order is C01 Constrictor, C02 Documents, C04 Supernova, C05 Cougar, C06 Occupied station. `new_mission` resets `jump_count` to `mission_rate = 64`, sets the mission word to `next_mission << 4`, then increments the next-mission counter. Normal hyperspace decrements the counter only outside galaxy index zero, while no mission is active; witchspace does not consume this normal-jump counter. At zero, start the next assignment. There is no inspected kill-score prerequisite for these five assignments. Refusing an offered assignment clears the current mission; it does not rewind the sequence counter. The initial saved commander's counter still needs a retail fixture.

Persist the mission word, next mission, jump counter, clue-hop counter and selected planet. `disk.m68` saves these values. Use generated planet IDs instead of hard-coding a BBC itinerary.

`galaxy.search` scans all 256 systems in ascending index, retaining the nearest and furthest by `square_distance`. Ties retain the earlier system because updates require strict improvement. `choose_planet` builds the local-chart rectangle around the current system, randomly selects a list entry, and retries the current system. The rectangle is inclusive at +/-25 x units and +/-20 y units (`common.def`). `square_distance` sums the two squared differences in generated chart coordinates. Preserve that coordinate generation and list order; this is not a random choice of any system within seven light years.

### C01 Constrictor

| State | Trigger and action |
| --- | --- |
| 0x10 | Docked offer selects the furthest system. Refusal clears mission; acceptance ->0x11. |
| 0x11 | Dock at selected system ->0x12. |
| 0x12 | Galactic jump ->0x13, selects the nearest system and sets clue counter to 5. |
| 0x13 | Dock at the current clue system: choose a different nearby system and decrement the counter. At zero ->0x14. The fifth clue docking selects the final destination. |
| 0x14 | Enter final destination ->0x15; pirate creation can supply the special Constrictor. |
| 0x15 | Constrictor destruction ->0x16. Escort generation is suppressed for this target. |
| 0x16 | Docked debrief adds 100,000 tenths =10,000 credits and clears mission. |

The Constrictor is energy-bomb immune. Exact laser/hull statistics remain in the selected ship resources. A launch-state 0x16->0x17 path exists in `main.m68`; reproduce or correct it only after a transition fixture establishes its intended effect.

### C02 Documents

State 0x20 uses the same furthest-system selector for its delivery destination. Acceptance ->0x21 installs one `documents` hold entry, sets fuel to 70 and missiles to four. While documents are carried, pirate leaders and escorts are replaced with Thargoids. Dock at the selected destination: remove documents, fit naval energy unit value 2, clear mission. This profile does not use the BBC Ceerdi/Birera collection leg.

### C04 Supernova

State 0x30 starts an in-flight fuel drain to zero and advances to 0x31. Its loop uses two-frame waits; do not substitute an invented wall-clock duration. Docking offer advances to 0x32 and clears all cargo before reading the player's answer, including when the player refuses. Acceptance fills spare hold capacity with refugees and advances to 0x33. In the rescue phases the sun's `snova` progression changes by 3,000 per sun-range update. Leaving the system with accepted refugees ->0x34; leaving without the accepted state ends the mission. Debrief clears refugees and sets the gemstones hold slot to raw value 1,000, overwriting rather than adding. The comment's unit wording is not sufficient to reinterpret that quantity as a different raw value. There is no verified Oolite-style 9/30-second timer in this profile.

### C05 Cougar

State 0x40 gives a docked warning and advances to 0x41. The special system-description warning and pirate-generation branch create a Cougar with two Asp escorts, subject to free object slots. A second Cougar is suppressed while the Cougar object counter is nonzero. The normal attack orbit uses the source's `rand_range`/`rand_limit`, orbit and vector-position helpers; do not substitute a hand-placed arrival-point target.

The Cougar header in `objects.dat`, interpreted through `common.def` and `main.m68:create_object`, gives energy 1,024, maximum velocity 30, turn rate 36, two missiles, ECM field 7, cargo type -1, canister field -1, mood 1, bounty raw 5,000 and kill rating 1,000. These are ST engine units. Energy bombs explicitly skip the Cougar. Within ECM range its missile-tracking branch chooses ECM without the ordinary probability test. Rendering hides the non-exploding Cougar when bit 6 of `loop_ctr` is set; `radar.m68` also checks that invisibility flag. This is frame-counter flashing, not an arbitrary cloak timer.

`orbit.m68:release_cargo` handles negative cargo types before the random canister-count branch: attempt exactly one canister carrying the same negative type. Object-allocation failure can prevent that drop. Laser destruction calls this routine, as does a successful missile hit. In `flight.m68:salvage`, the player needs a fuel scoop, positive/nonnegative forward z and negative y. After those tests, negative cargo directly increments the fitted cloak field, before the ordinary cargo-capacity check. Mark the canister removed, lose its target and report successful salvage. A full ordinary hold therefore does not block this special equipment award. Destroying the Cougar alone does not fit the device.

`main.m68:remove_object` clears the mission when a Cougar is removed, independently of whether its canister was recovered. There is no separate successful-scoop debrief in this source path. Losing the dropped canister can end the assignment without its equipment reward. The cloak toggle requires fitted equipment and flight, then inverts the active flag. Core acquisition is now R1 for this pinned source; original binary, full attack AI, object-pool pressure and escape/reload behaviour still require fixtures.

### C06 Occupied station

Docked warning 0x50->0x51. The next system departure advances to 0x52, so the next selected destination is the occupied system. System creation in 0x52 creates a Dodecahedron station, suppresses normal shuttles and uses Thargoids in place of police; a station launch counter of 200 frame units controls reinforcement generation. Normal automatic docking is blocked. Destruction sets `station_destroyed` and advances to 0x53. Docking elsewhere fits ECM jammer value 1 and ends the mission. Match the target station's original resource hull and laser rules before claiming full combat parity.

### ST fixtures

Check 63/64 eligible jumps, galaxy-zero jumps, witchspace, refusal, save/reload of selected planets, each of the five clue hops, cargo wiped on nova refusal, gemstone overwrite, Cougar drop lost versus scooped, and occupation of the next jump destination. Save the exact selected planet list and RNG state so another run can reproduce the route.

## GBA The New Kind source profile

Evidence: S37, `missions.c`, `swat.c`, `elite.c`, `elite.h`, `file.c`. The repository is named 1.7.1 but its README identifies 1.6. Treat this as a pinned source profile until matched to a ROM.

C01 starts at score >=256 (easy mode >=192), while mission state is zero and galaxy index <2. Its target is galaxy index 1/system 193. Destruction ->state 2; docking pays 5,000 credits and 256 score, ->state 3. C02 requires state 3, galaxy index 2 and score >=1,280 (easy >=960), ->state 4. Collection checks planet seed bytes d=215,b=84 and advances to 5; delivery checks d=63,b=72, awards naval energy and 256 score, ->state 6. The coordinate collection/delivery predicates themselves omit a new galaxy check: retain this distinction if reproducing source behaviour.

### C08 repeatable asteroid assignment

Eligibility: mission 6, score >=1,700 (easy >=1,536), in stored target galaxy but docked at a different planet from the target. Briefing ->mission 7. The quota is `MISSION3_LIMIT = 30`. Every `SHIP_ASTEROID` passed to `explode_object` while state 7 increases the count up to 30, regardless of system. Boulders do not count. A subsequent asteroid destruction at count 30 prints the completion notification and advances to 31; docking success already accepts count >=30. Do not require the notification as an extra objective.

At a station safe zone in the selected system, while count <30, an encounter check can spawn the storm. Return immediately when `rand255() >=225` or there are already >=15 asteroids. Otherwise a second random byte <100 produces one asteroid with velocity 8, rotx 16 and rotz +/-127. The other branch uses z=8,000, independently signed x/y=`1,000 + GetRand(8191)`, then `(rand255() & 3)+1` bodies at that position, each an asteroid when its random byte >50, otherwise a boulder. Speeds are `(randomByte & 16) | 8`, thus 8 or 24. Positions are converted to the engine's fixed-point coordinates by shifting left eight bits. The single-spawn helper uses z=12,000 and x/y=`1,000 + (GetRand(65535) & 8191)` with independent signs. Comments claiming only one to three bodies are inaccurate: the loop can create four.

Dock at the target with count <30: reminder, no reward. At count >=30: add 6,000 credits, reset count to zero and state to 6; select the next galaxy `(oldGalaxy + 1 + rand()%3) & 7` and system `rand() & 255`. This makes the assignment repeatable. The mission state, count and selected destination are saved in `file.c`.

**Source defect:** `elite.h` orders initial fields as planet then galaxy, but `elite.c` supplies 3 then 248 with comments claiming galaxy then planet. The resulting source initializer gives planet 3/galaxy 248, which fails ordinary galaxy eligibility. Do not silently assert an initial target of galaxy 4/system 248 from those comments. A ROM/start-save or corrective source revision is required to resolve the shipped destination.

Required fixtures: easy/normal boundaries, count 29->30, the optional 31st-kill message, off-target kills, boulder non-credit, 15-body cap overshoot during a batch, target docking, repeat-destination selection, initial commander fields and saved-game round trips.
