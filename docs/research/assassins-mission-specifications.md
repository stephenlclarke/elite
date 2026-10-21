# Assassins Guild Rebooted campaign

O07 P01 is the downloaded 2.7 package (SHA-256 in [package provenance](data/oolite-pack-sources.json)). Its main script identifies itself as 2.6, dated 08/08/26. This is a rewrite of the older Assassins Guild, so it must not silently stand in for 2007 version 1.3.3. The package advertises 21 interlinked missions; its source contains ten assassination contracts, revenge encounters, news/world changes and an original Black Mesa adventure that the owner has now excluded. Those are different counting units.

The [structured profile](data/assassins-mission-profile.json) holds retained contract stages/target definitions, the docked supply adaptation and source paths/hashes. The [25 active source fixtures](data/assassins-source-fixtures.json) check ten player/NPC kill distinctions, Inno Soin's different death predicate, eleven debrief payments and three pylon capacities. The full original adventure evidence is archived and excluded. These execute original callbacks with a mocked Oolite API; they do not reproduce physics or prove a released Oolite outcome. All 504 package resource definitions and core inheritance are in [expansion resources](data/oolite-expansion-resources.json), with no unresolved parent in P01. They include templates, stations, role variants and components, not 504 unique ships.

## Entry, persistence and encounter rules

Run the story in galaxy 7, source galaxyNumber 6. Start the first contract while docked outside system 73 with score >199. Read and persist assassins_rebooted_stage, jumpcounter, interlude, battlebot_development, battlebots_escaping, battlebots_escaping_timer, thargoid_invasion, navy_base_lockdown, civil_war, deamons and reinforcements. Adventure page/card/trumble/shooting fields are excluded from the project state. Source initialization tests the stage's truthiness: stage 0 is treated as uninitialized on reload. A project repair must test absence instead; preserve this distinction in a historical profile.

The source jump counter advances on hyperspace exit, including outside galaxy 7, and caps at 99. Story screens/population are restricted to galaxy 7. Most screen callbacks reset the jump counter. Thresholds below mean the actual strict source comparisons; comments often describe a different number of jumps. Docking screens can advance more than once across callbacks, so record screen ownership and apply each transition/payment once.

Each of the ten victims advances only when its death callback receives a player killer. An NPC kill does not complete the contract. Player legal changes use bitwise OR, not addition. Targets 2-10 temporarily replace a working cloak/energy bomb with a dummy item; damaged equipment is not exchanged. Restore only an owned dummy on a credited kill or the source restoration/population event. This must cooperate with shipyard storage and unique item ownership.

## Ten contracts

All system IDs in this table are in galaxy 7. Stage triples are active / credited kill / docked debrief. Fees are explicit debrief payments; engine kill bounty is separate.

| Sub-ID | Target and system | Stages | Fee credits | Player bounty OR | Important encounter |
| --- | --- | --- | --- | --- | --- |
| P01-A01 | Be Soin, Pride and Joy; 73 | 1 / 2 / 3 | 180 | 10 | Vintage Adder within radius 20,000 of Sunset Retirement Home. Stage-2 debrief is suppressed at the Corpse Bride station. |
| P01-A02 | Hockey team, Victory Lap; 194 | 6 / 7 / 8 | 4,320 | 65 | Armoured liner 150,000 ahead of the orbital stadium; four escorts in its dictionary. |
| P01-A03 | The Fair Wind; 203 | 14 / 15 / 16 | 9,000 | 70 | Anaconda within radius 10,000 of the repair facility. |
| P01-A04 | Inspector Thorstan, High Noon; 18 | 20 / 21 / 22 | 15,000 | 75 | Asp at base position +[1,000,0,0], radius 8,560; two escorts. |
| P01-A05 | Logan 5; 39 | 24 / 25 / 26 | 22,500 | 0 | Control drone on wpu route fraction 0.44, with support at 0.15, 0.25, 0.35, 0.55, 0.79 and 0.89. |
| P01-A06 | O-Ren Ishi, Lady of the Dead; 81 | 30 / 31 / 32 | 0 | 0 | Duel beacon at pwm [250000,300000,840000]; inspect its ship/AI callback for duel arrival. |
| P01-A07 | Boss Yankisona, Atom Smasher; 53 | 35 / 36 / 37 | 31,500 | 0 | Triad Boa 155,000 ahead of the Mafia waystation; fee already includes the agent's deduction. |
| P01-A08 | Bi Xea'nu, Indefatigable; 82 | 41 / 42 / 43 | 36,000 | 80 | Frigate within radius 7,500 of locked-down navy station. Kill clears lockdown. |
| P01-A09 | Claudius Maximus, Vengeance; 13 | 47 / 48 / 49 | 9,000 | 85 | Flagship at main-station position +[20000,0,0], radius 1,000; four escorts. |
| P01-A10 | Governor Tarkin, Balrog; 13 | 55 / 56 / 57 | 0 | 0 | pwm [-200000,-700000,260000]. Dictionary bounty 50,000 is an engine kill reward; do not pay another 50,000 at debrief. |

The target values below are dictionary values before script equipment, fuzzy properties, subentity weapons and engine behaviour. They are NPC energy, not player shield bars. The full definitions retain ECM, missiles, turrets, escorts, weapon positions and scripts.

| Victim | Energy | Recharge | Speed | Forward weapon | Missiles | Escorts |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 100 | 2 | 250 | Pulse | 0 | none specified |
| 2 | 750 | 1 | 290 | Beam | 4 | 4 |
| 3 | 700 | 3 | 250 | None | 0 | none specified |
| 4 | 450 | 4.5 | 450 | Military | 1 | 2 |
| 5 | 1,000 | 3 | 250 | None | 2 | 4 |
| 6 | 525 | 3.8 | 400 | Military | 2 | 2 |
| 7 | 625 | 3 | 380 | Military | 3 | 2 |
| 8 | 750 | 2 | 550 | Military | 2 | 2 |
| 9 | 1,750 | 1 | 300 | Thargoid | 6 | 4 |
| 10 | 75,000 | 100 | 350 | None | 10 | none specified |

## Inter-contract state graph

Use the numbered contracts above for the recurring hunt/kill/debrief path. This table supplies the intervening offers and revenge/news gates. A system exclusion means the screen waits until docked elsewhere. Unless a location is explicit, ordinary permitted docking is sufficient.

| From | Gate/action | To |
| --- | --- | --- |
| 3 | Dock at Torus Station: Corpse Bride; award Mark Transponder Scanner. A hostile arrival variant forces launch. | 4 |
| 4 | jumps >4, news | 5 |
| 5 | jumps >4, outside 194, offer A02 | 6 |
| 8 | jumps >6, revenge message, interlude Yes | 9 |
| 9 | Micro-Mamba revenge encounters over jumps 1-8; jumps >8 ends run | 10 |
| 10 | Dock, pay 500 | 11 |
| 11 | Launch with jumps >2, spawn Inno Soin near player at +[10000,0,0], radius 10560; reset jumps | 11.5 |
| 11.5 | If jumps >1 without killing him, respawn at witchpoint and reset | 11 |
| 11 or 11.5 | Inno Soin dies, even to an NPC; clear interlude, spawn five bombs | 12 |
| 12 | Dock, pay 1,000 | 13 |
| 13 | jumps >2, outside203, offer A03 | 14 |
| 16 | jumps >3, news | 17 |
| 17 | jumps >1, news | 18 |
| 18 | jumps >2, outside18; invasion state1 | 19 |
| 19 | jumps >1, outside18, offer A04 | 20 |
| 22 | jumps >4, outside39; battlebot development1 | 23 |
| 23 | jumps >4, outside39, offer A05 | 24 |
| 26 | Development2 and escaping level1; jumps >5, outside13; civil war1 | 27 |
| 27 | jumps >4, news; interlude Yes | 28 |
| 28 | Hockey-fan revenge: jump1 near station, jump2 wpu 0.11, jump3 witchpoint; jumps >3 ends interlude | 29 |
| 29 | Outside81, offer A06 | 30 |
| 32 | jumps >2, outside39; development3 | 33 |
| 33 | jumps >1, news | 34 |
| 34 | jumps >2, outside53, offer A07 | 35 |
| 37 | Launch with jumps >0; spawn Triad Wasp, reset jumps | 38 |
| 38 | Revenge spawns at jumps1/2; special extra in system 100; jumps >3 ends interlude | 39 |
| 39 | News | 40 |
| 40 | jumps >1, outside82, offer A08; lockdown Yes | 41 |
| 43 | jumps >3, outside18; development Complete, invasion2 | 44 |
| 44 | jumps >2, outside13; deamons Lawful | 45 |
| 45 | jumps >4, outside13, news | 46 |
| 46 | jumps >1, outside13, offer A09 | 47 |
| 49 | jumps >2, outside13, news | 50 |
| 50 | jumps >4, outside13; civil war2, clear deamons/reinforcements | 51 |
| 51 | jumps >3, outside18; invasion Over, interlude Yes | 52 |
| 52 | First later population with jumps >0 adds Mongoose revenge wing, clears interlude | 52 |
| 52 | jumps >4, outside71; offer Black Mesa journey | 53 |
| 53 | Confirm docked missile supply; no on-foot adventure | 54 |
| 54 | Main station at 71, offer A10 | 55 |
| 56 | Credited kill has cleared player bounty and spawned cavalry; dock, remove Gravitons | 57 |
| 57 | jumps >2, outside13; civil war Over, democratic government6 | 58 |
| 58 | jumps >0; set old compatibility variable assassins_COMPLETE and clear story | Complete |

The independent escaping-battlebot timer increases with jumps. At >4, >9, >14, >19 and >24 it advances through levels2-6; >29 marks Complete and removes the timer. Six infested systems remain a world change. Civil-war ownership changes which ships are lawful, station permissions, population and productivity. Preserve these fields when saving or changing player hull; news is not merely decorative text.

Inno Soin's death adds bomb roles in spheres of radii 5,000, 10,000, 15,000, 20,000 and 25,000 around the player. The source comment calls their countdown 0.5 seconds; linked AI and original engine timing still need a direct fixture. The player must survive to dock for the second revenge payment.

## Docked supply and retained flight finale

The owner confirmed keeping separate space missions within mixed campaigns and the planned space-station supply adaptation. The entire playable adaptation uses space flight and station services; the original Black Mesa adventure remains reference-only. Implement the [flight-only adaptation](implementation-scope.md#p01-flight-only-adaptation): at stage 53, confirm a docked missile-supply transaction, store the personal loadout and install capacity-bounded unique quest Gravitons, then advance54. No adventure pages, card/Trumble puzzle or stormtrooper choices remain active. The Angeriri main-station briefing then starts the retained stage 55 Balrog encounter.

The Graviton AI pauses 0.5 seconds, searches for the Balrog role, intercepts to range25 and has a30,000 travel cutoff. Detonation calls dealEnergyDamage(999999,25,0.10). Balrog's large energy/recharge, turret subentities, target dummies and fleet battle remain ship-based. A blank front weapon does not make it unarmed. Credited death advances56, changes civil war state, clears player bounty and summons cavalry; its50,000 engine bounty is paid once.

Use identity-based quest-missile cleanup and restore compatible stored personal rounds after the finale. The source's missile-array comparison and first-missile cleanup defects remain historical evidence, not the storage policy. The active source fixtures include three loading-capacity checks; project storage/transaction tests are still required.

## Necessary project repairs and acceptance

The owner permits labelled estimates only when needed. Retain a historical source profile and a separate repaired project profile. Required repairs are an absence check at initialization, capacity-safe quest missile replacement/storage, identity-based Graviton cleanup and persistent one-time screen/payment handling. These are explicit project behaviour choices. They do not authorize inventing a different reward when the source supplies one.

Check score 199/200, galaxy 6/7, each excluded system, exact jump threshold and threshold+1, NPC/player/environmental kills, damaged cloak/bomb, save/reload at every retained contract/supply stage, one/ten/more-than-ten pylons, mixed missile order, lost Gravitons, hull changes during a hunt and a single 50,000 final engine bounty. The saved25 active fixtures verify attribution, fees and three historical missile-loading capacities. Full spawn/AI event ordering, every world-population branch, source-to-engine version compatibility and original outcomes remain runtime work; the structural rule index does not close those checks.
