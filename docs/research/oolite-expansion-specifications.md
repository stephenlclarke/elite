# Oolite expansion mission specifications

This supplement begins replacing the pack-name-only inventory with inspected behaviour. Source O07 is the expansion manager's catalogue and the downloaded packages identified in [data/oolite-pack-sources.json](data/oolite-pack-sources.json). Each record retains the package URL, version, SHA-256, dependencies, author, licence and hashes of inspected text files. A downloaded package is not automatically a verified mission specification. Only profiles explicitly analysed below have advanced beyond discovery readiness.

Galaxy and system indices below are zero-based. Engine distances are metres, timer intervals seconds and `player.score` is combat score. Preserve missionVariables strings, choice handling and original event order. The base Oolite version and its default ship templates/AI are additional dependencies; this reference does not bundle third-party dialogue, models or scripts.

## P03 Asteroid Storm, package 4.3

Evidence: `Scripts/AsteroidStorm.js`, `Scripts/LBbadrock.js`, `Scripts/LBAsteroid.js`, `Config/shipdata.plist`, `AIs/badrockAI.plist` and mission text. The world script internally labels itself 4.03. Core objective/outcome logic is R1; exact engine presentation and save/reload of transient entities remain separate parity work.

Offer at the main station in Leesti, galaxy 0/system 55, with score >63 and no prior asteroid mission. Briefing sets `asteroids_BRIEFED`; launch sets `asteroids_RUNNING`. Select giant role badrockI below score 96, badrockII below 180, otherwise badrockIII. Their max energy is 1,100/1,500/2,000, speed 150, recharge rate 1, pitch/roll 0.4, thrust 300 and no missiles/ECM. Remove a fitted energy bomb for the encounter when that equipment exists in the engine.

Place the giant along the vector from station toward the direction away from the planet, using a rounded random distance 4,000-20,000 from the station, then use a 10-metre spawn radius around that position. Set its custom recharge buffer to `(distance/7000)-1`. Create four miners and 27 small mission asteroids. The giant's mining hits are undone; while the custom buffer is >=0, incoming damage reduces the buffer by damage/maxEnergy and energy is restored to maxEnergy. Once the buffer is negative, ordinary damage can destroy it. Do not implement this as an ordinary 2,000-energy rock with no buffer.

The giant AI targets the main station and flies at speed factor 1. On reaching desired range 100 or a close-contact event, it enters detonation: damage within 2,500, notify the script and explode. Its death sets `asteroids_OVER` and the giant-dead marker. A station killer, cascade weapon, or a last recorded energy >half maxEnergy invokes station loss. The latter is the source's superweapon check, not a generic mission rule that all high-energy kills destroy stations. That branch also throws 13 of 20 spawned rocks toward the station at random speed 500-1,500.

Kill credit is player when the final killer is player OR the last attacker recorded by the ship script is player. An NPC final blow can therefore leave player credit. On normal successful debrief pay 1,000 credits for player credit or 350 for NPC credit. Player credit also clears bounty and can restore an energy bomb if supported. The station-loss/attempted-defence branch pays 200 credits. Hyperspace departure while the giant is still alive records cowardice and station loss; the later mission-screen debrief subtracts 200 credits and adds 25 bounty. Persist the station-dead state; the damaged-system population path divides system productivity by 100. These branches must be evaluated using the exact world-script state rather than collapsed into one "failure" result.

Station destruction has a 25% immediate-explosion branch; otherwise it launches five emergency shuttles and one miner, sets energy to 100 and uses a rounded random 18-38-second destruction delay. Docking interrupts the delay; subsequent launch schedules a 3-19-second delay. Read the package's `wipeStation` paths together with death callbacks because engine versions historically differed on whether scripted explosion invokes `shipDied`.

Persist `missionVariables.asteroids` and `asteroids_statdead`. Giant killer/last-hit data and timer objects are transient script fields. A save-anywhere remake must specify whether it serializes those extra fields or deliberately emulates a restart. Required checks: scores 63/64, 95/96, 179/180; recharge crossing zero; miner hits; NPC finisher after player hit; station collision; cascade damage; normal and cowardice payouts; docked station-loss delay; post-reload destroyed station.

## P04 Bank of the Black Monks, 2.4

Evidence: `Scripts/blackmonk_main.js`, `Scripts/blackmonk_fuel.js`, `AIs/blackmonk-gunshipAI.js`, ship/equipment definitions and mission text. Core loan, route, deadline and repayment graph is R1; the port-weapon typo, engine replacement transaction and resource/AI behaviour need runtime verification. This repeatable financial pilgrimage is one generated contract family, not a new canonical mission for each destination.

### Offer and route calculation

At startup and on entering a new galaxy, select non-nova systems with government >=6 and tech level >=11. Retain a system only if at least one other selected system is reachable with `routeToSystem(...).route.length >9`. Monastery population uses deterministic `LANE_WP`, location seed 937, one monastery plus ten minesweepers within 15 km. The bank interface is available while docked at a monastery. Only hyperspace-capable ships can take a new loan; one contract can be active.

List reachable monastery destinations with route-array length >9, sort by that length and keep the first five. The deadline allowance is `ceil(route.time/24) + ceil(route.length/12)` whole days. The source comment describes half an hour per system, but that is not the implemented equation. Switching the displayed map between shortest and quickest does not change the `_setOffer` calculation's default `routeToSystem` call. Signing adds 20,000 credits, stores galaxy/system and `dealine = clock.seconds + days*86400`, and marks the destination. Preserve the misspelled stored key when importing saves.

### Repayment and default

A qualifying repayment port is a monastery in the exact stored galaxy/system, OR any monastery after changing galaxy. Before or exactly at the deadline, repayment is optional and needs >=30,000 cash credits. After `clock.seconds > dealine`, a qualifying monastery forces the repayment screen and invokes the payment routine. An early arrival with insufficient cash remains pending; the equipment liquidation branch is reached through forced late payment. A monastery in the wrong system of the original galaxy cannot settle the debt. Successful settlement clears the marker and contract, allowing another pilgrimage; there is no completion bounty.

Payment first deducts 30,000 if cash suffices. Otherwise, assess working positive-price equipment, missiles and lasers at their equipment prices divided by ten; exclude cargo-bay extensions and passenger berths. If cash plus equipment valuation suffices, sell until cash reaches 30,000, then deduct the debt. Sale order is missiles, eligible equipment, port laser, starboard laser, aft laser, forward laser, preserving array order within equipment categories. Damaged equipment is excluded. The port-laser sale credits its value but assigns `player.ship.boardWeapon = null`, a typo distinct from `portWeapon`; its actual runtime effect must be tested and must not be silently corrected in a historical profile.

If equipment plus cash is still insufficient, sell the available equipment, credit half the old ship's mint price, replace the player ship with `adder-player`, remove heat shielding and a missile, and set service level 75. Then deduct 30,000 and the new ship's price. Test the engine's `replaceShip` semantics, cargo/passenger survival and a resulting negative balance before treating this as a fully verified transaction.

### Pursuit, ships and persistence

Each populated system after the deadline creates a witchpoint group of `min(5, ceil((clock.seconds-dealine)/86400))` gunships. Equality at the deadline creates no punishment group. Ambient gunship probability is 0.1 without a contract; with one, let `d = ceil(dealine-clock.seconds)/86400`. For d>=2 use `max(0.2,2/d)`; for d<2 use 1. Ambient encounters also create fuel-less debtor traders. These extra ships are not additional objectives.

Gunship AI first continues existing combat; otherwise it attacks a nearby overdue player, then seeks a debtor within 25,600, then patrols the spacelane. The combat and overdue checks reconsider after five seconds, debtor search after twenty and patrol after thirty. The Holy Avenger Mark II gunship has energy 1,400, recharge 6, speed 150, thrust 30, pitch 0.5, roll 0.6, ECM, injection, shield booster and six hardened missiles with five-second load time. It has no hull forward laser; two wing subentities carry military lasers with weapon-energy field 30, plus a turret with fire-rate field 0.5, range 6,500 and energy 50. Full engine meanings and model geometry remain external dependencies.

Before saving, serialize the contract as JSON in `missionVariables.blackmonk_contract`; startup restores it into the world-script contract and deletes the temporary saved key. Holy Fuel is an optional bank product, not a mission prerequisite: it sets displayed fuel to 7 and condensed fuel to 10.5, transfers 0.1 per render callback while conditions permit, and has its own saved mission variable. Normal fuel purchase clears condensed fuel. Its frame-dependent refill and monitor restart after loading need a parity fixture.

Required checks: route lengths 9/10, exactly five/six offers, rounded day allowance, decline/exit, exact deadline equality and one second late, wrong port, another galaxy, early insufficient cash, forced cash/equipment/ship payment, port-laser typo, negative final balance, one/five late-day groups, repayment while already pursued, and save/reload before each transaction. No kill quota resolves this debt.

## P23 Long Way Round, 2.2

Evidence: `Config/script.js` and `Config/shipdata.plist`. R1 core graph. Correct the discovery-index alias "Long Way Around" to the package title "Long Way Round".

| State/event | Behaviour |
| --- | --- |
| Main-station docking, G0/system 3 Biarge, no mission | Automatically show instructions and set STAGE1; destination 248 Soladies. No score gate or accept/refuse choice. |
| Main-station docking, system 248 in STAGE1 | Pay 500 credits; STAGE2, destination 233 Qubeen. |
| Enter system 233 in STAGE2 | Add two `longWay_rebel`; start one-second repeating timer after one second. |
| Timer counters 1-59 | If role count <5 and random <0.5, add one rebel. Counter 60 stops timer. Invalid player ship/out-of-space also stops. |
| Main-station docking, system 233 in STAGE2 | Pay 2,000 credits, MISSION_COMPLETE, clear instructions. |

Rebels inherit the Krait template with pulse laser, ECM, escape pod, energy 300, speed 200, roll 1.75, pitch 1, two missiles, no cargo and pirateAI. No kill quota, explicit delivery cargo or deadline exists in this world script; survival to docking is enough. The timer's fewer-than-five test is a population condition, not a five-kill objective. Test docking without kills, a ship leaving space while the timer runs and save/reload between the two payments.

## P33 Scourge of the Black Baron, 2.1

Evidence: `Config/script.js`, `Config/shipdata.plist`, dependency manifest. R1 core graph.

Requires P23 completed, score >150, main-station docking in G0/system 243. Accept ->STAGE1; reject ->MISSION_COMPLETE permanently without payment. In STAGE1 dock system 93: +1,000 credits, STAGE2 destination 180. In STAGE2 dock 180: +5,000 credits, MISSION_COMPLETE and clear instructions. No required Baron kill is checked by this script.

While STAGE2 in G0, entering system 180 creates seven minions. Systems 222 and 48 start a timer after two seconds, repeating every eight seconds: nine attempts at 222 or six at 48. On each relevant attempt, if minion count <7 and random <0.5, add one. Minions are Krait derivatives with pulse laser, ECM, escape pod, energy 300, speed 250, roll 1.75, pitch 1, no missiles or cargo, pirateAI. Entering galaxy index 1 during the active mission terminates it without payment; this is an explicit G1 check, not a general rule covering every possible galaxy change.

Test 150/151 score, missing dependency completion, rejection persistence, wrong-order ports, immediate docking without combat, timer count limits, G1 abandonment and repeated final docking.

## P35 Spy Hunter, 2.0

Evidence: `Config/script.js` and `Config/shipdata.plist`. R1 core graph. The indexed "512 kills" shorthand is not the exact gate: inspected code requires score >512, meaning 513.

All mission-screen gates require G0, main-station docking and score >512. Dock system 158: automatic orders ->STAGE1. Dock 164: +1,000 credits ->STAGE2. Dock 51 ->STAGE3; dock 102 ->STAGE4. Populate system 126 in STAGE4 with one `spyhunter_impcourier` if none exists, at `Vector3D(0,0,0.1)` converted from `wpu` coordinates. Chain its original death callback, then advance STAGE4->STAGE5 when it dies, regardless of who killed it. Dock system 126 in STAGE5: +4,000 credits, MISSION_COMPLETE, clear instructions. No explicit time limit.

The target has energy 1,050, recharge 4, speed 600, thrust 30, pitch 2.75, roll 3.5, six missiles, military forward laser, ECM and fuel injection, no escape pod, bounty 550 and 0.1 shield-booster probability. Its two engine subentities carry beam lasers. It uses `oolite-pirateAI.js`. Values such as fuel=600 are raw shipdata fields and must be interpreted by the selected Oolite engine; do not reinterpret the number from its display alone.

Test score 512/513, each briefing stage, duplicate population suppression, NPC kill completion, target destruction before STAGE4, reward station, and repeated debrief. The target hull is a mission variant of Imperial Courier, not a newly discovered biological species or a duplicate general model.

## P27 MincePie, 1.1

Evidence: three `Scripts/*.js`, `Config/equipment.plist`, `Config/shipdata.plist` and `AIs/hungrySantaAI.plist`. R1 core interaction after inspecting its Santa 1.2 dependency; engine and asset parity remain separate. This is a seasonal interaction, not a conventional accepted contract.

At startup/reset, if the computer's real local month is December and day <26, and world script `santaClausMain` is present, set mince-pie equipment effective tech level to 1. Otherwise clear its tech-level mission variable. Equipment price field is 250 internal tenths (25 credits), uses an empty missile pylon and is available to all ships. Outside that date interval, the first launch handler removes installed pies and then deletes itself. Do not replace this real-date gate with the Elite simulation calendar.

Deploying the pie makes it stationary. If no Santa exists, add one, then attach hungrySanta.js to every Santa. A ten-second initial/repeating search finds pies within 20 km. AI scans every five seconds and approaches to 50 m, waits three seconds to orient, then five seconds to eat; the script requires a pie within 100 m to remove it, create an eaten-pie object, then select one of four present definitions (1,3,6,7) with equal array-index probability. A six-second burp timer follows. With no pies left, stop the timer and remove search hooks. Santa 1.2 supplies the four gift definitions: prezzie1 contains two gold units, prezzie3 and prezzie7 luxuries, prezzie6 liquor/wines. The commodity units follow Oolite's market definitions. The reward-ejection block runs even if no pie was found within 100 m when the eating callback fires; preserve this edge case separately from a corrected design. Santa normally flies toward the planet, rechecking every ten seconds; attack invokes escorts and a 2.5 speed factor escape. Its world script naturally spawns Santa with probability 0.33 on arrival only December 16-30, while a deployed pie can spawn him independently during MincePie's December 1-25 availability. The sled has energy 550, recharge 3, speed 180, thrust 20, pitch 0.8, roll 2, injection and shields, plus five armed reindeer escorts. Destroying it releases twelve random presents, its list and a hat. Scooping the list grants a letter equipment flag; a qualifying seasonal main-station screen removes it and pays 30 credits. These are dependency interactions, not extra copies of P27. Test the two date intervals, no-pie callback reward, gift contents, interrupted approach and repeated deployments.

## P24 Lost Worlds Grand Tour: activity classification corrected

GalDrivePod1.4is an equipment package. Its author describes Lost Worlds Grand Tour as a suggested travel activity; no separate mission-bearing historical distribution is established. See [Grand Tour specification](grand-tour-specifications.md) for the documented route, independently verified named endpoints and an explicit project journal. The prior requirement to find an assumed lost campaign graph was unsupported and is removed. This does not prove exhaustive historical revision parity.

## Remaining packages

The original manifest records40 fetched revisions (37 indexed records plus the Santa dependency, historical Military Fiasco 2.5.3 and recovered Xeptatl's Sword3.0), including Assassins Guild Rebooted 2.7 with 21 advertised interconnected missions. That is a rewrite of the old Assassins Guild and must not silently be treated as identical to the 2007 pack. Aquatics' catalogue version and download filename also disagree; preserve both in the manifest. Cataclysm, TCAT and Trident Down now have dedicated source-backed specifications. Coyote's Run, GalCop Missions, Iron Raven, Random Hits, Rescue Stations and UPS still require semantic closure; download alone does not close their coverage gaps.

Additional recovery now covers P05, P13/P14 (shared modified Navy distribution), P16, P21, P22, P28, P32, P46 and P47; there is no remaining unfetched pack ID in this catalogue. P46 still requires mission analysis. P21 has the [LinkG7 rift trial](linkg7-mission-specifications.md), P22 the [31-assignment Localhero profile](localhero-mission-specifications.md), and P16 the [11-archetype Most Wanted generator](most-wanted-mission-specifications.md). Provenance and selected edition differences remain separate from runtime parity; archive recovery is not semantic completion of the remaining campaigns.

## P36 Stealth, 2.2

Evidence: `Config/script.js`, `Config/shipdata.plist`, all three ship scripts and the Barracuda/base/mine AIs. R1 core objective and outcome graph. The internal scripts label themselves 1.06; preserve the package version separately.

Offer at the main station in Beenboer, G2/system 116, with score >=512. Suppress mission screens while TCAT has an active state other than OFFER/CASE_CLOSED. Acceptance passes through ACCEPTED to GO_GET_EM; refusal passes through REJECTED to CASE_CLOSED. The next screen opportunity supplies the corresponding briefing. Mark Lequena/system 131. Population there creates one hidden base at a random fraction 0.25-0.75 of the witchpoint-to-station route, if no base already exists. Docking there can give a hint; it is not a checked prerequisite for attack.

The base inherits the rock-hermit template, has energy 2,500, recharge 5, ECM, no forward laser, no ordinary traffic, at most six defence ships and rock scanner classification. Spawn 30 asteroids within scanner range and ten mines within 0.785 times scanner range. A one-second watch launches two Barracudas when the player comes within scanner range. Attacks launch a defender with probability `(maxEnergy-energy)/maxEnergy`. On low energy, attempt to launch the remaining complement. Engine launch limits remain binding.

Barracudas have energy 512, recharge 4, speed 350, thrust 50, pitch 2.5, roll 3.5, beam lasers fore/aft, six missiles, ECM, injection and bounty 500. Score >512 adds shield boosters; >2,560 also adds enhancers. Each spawned Barracuda increments the launch counter. Each death increments the kill counter without checking killer or cause: this counter is not restricted to player kills despite its comment. Their scanner colour becomes red during attack and transparent outside it; low-energy flight exposes them. AI recovery polls after five seconds, then every ten; pursuit/flee ranges are 7,500/25,600.

Mines have energy 200, recharge 1, speed 100 and damage field 9,000. Every five seconds their idle AI can detect a merchant target; a one-in-three dice branch activates interception. Approach range 25 detonates with damage within 500. ECM rolls five outcomes: 1 deactivates, 3 detonates, 5 explodes; the other results retain interception. Travelling beyond 50,000 schedules an explosion after random 0.25-3 seconds. Destroying a mine alerts the base to the killer.

A base death with a nonempty cause other than `removed` sets BASE_DESTROYED, regardless of killer. Entering witchspace from the encounter while it survives sets BASE_INTACT. Merely starting a jump countdown warns without deciding the outcome. At the Beenboer main-station debrief, both outcomes close the mission. With the base destroyed: six counted Barracuda deaths pay 2,000 credits; three to five pay count*250; zero to two pay nothing. With the base intact: six pay 1,000; three to five pay count*100; zero to two pay nothing. No default payout branch handles a counter above six. Entering galaxy index 3 with a state other than OFFER closes the case; do not generalise this to every galaxy number.

Docking at the hostile base forcibly launches the player, applies two internal-damage calls, multiplies energy by a random factor 0.5-1 and each shield independently by 0.1-0.9. A library configuration option can reset a closed case to OFFER and zero both counters; ordinary completion is otherwise one-off. Mission state and counters are missionVariables, while the group, base, timers and hint flag are transient.

Required checks: score 511/512/513 and 2,560/2,561; TCAT suppression; refusal; base destroyed by NPC; Barracuda deaths by NPC or removal; each payout counter; departure with/without base loss; mines under ECM; hostile-base docking; explicit replay reset; save/reload of transient encounter state.

## P37 Stellar Serpents, 1.21

Evidence: all three `Scripts/stellarSerpents_*.js`, `Config/shipdata.plist` and `AIs/stellarSerpents_serpentAI.plist`. R1 population/reward core; animation event order, engine combat and full mesh parity remain R2. This is a recurring announced hunt; there is no accept/refuse contract or hand-in reward. The creature is an Oolite expansion entity, not a new official Elite alien race.

Initialize NO_SERPENT, life=0 and INITIAL_BROADCAST when the corresponding mission variables are absent/falsy. On ordinary-system arrival (also the first launch after startup), create an existing serpent at the tracked location only if no head role exists. Then, if status is NO_SERPENT, random <0.1 creates a new tracked serpent in `floor(random*256)`. In galaxy index 2, location 133 or 206 is shifted by `ceil(random*40)`. The spawn test occurs before this new-location selection, so choosing the player's current system does not immediately create the head in the same handler. Interstellar space skips the arrival handler.

On entering witchspace, one random value determines movement: <=0.45 stays and increments life; >0.45 and <0.9 increments life and selects a random system from the current serpent location's `systemsInRange(7)` array; >=0.9 destroys it offscreen only if life was already >3, otherwise it stays and increments life. There is no wall-clock lifespan. A galaxy change clears status and instructions; do not assume the old serpent persists independently in every galaxy. Main-station docking displays one pending initial/appearance/NPC-kill/player-kill notice, then clears the notification. Location instructions track movement separately.

Head death with cause `removed` leaves the tracked hunt unchanged. Other head deaths clear the serpent. Player reward credit includes a player killer, a killer owned by the player, or either role `hiredGuns_escort` or `aquatics_guardianPlayer`; those role checks do not independently prove actual ownership. This branch immediately adds 500 credits and explicitly adds one score point; main-station docking only reports it. `counts_as_kill=yes` is also set on the head, so verify how the selected engine combines its ordinary kill increment with the script's extra point. Body/tail objects have `counts_as_kill=no`, zero bounty and no separate mission payout. Other killers produce the NPC notification without the script payment.

The head has energy 2,000, recharge 2, speed 300, pitch/roll 0.5, thrust 0, no ECM/missiles/drive, rock scanner class, beam-laser type with hull weapon-energy field 0, two Thargoid-laser subentities and two turrets with weapon-energy 35. Each body/tail has energy 1,000, recharge 1.5, zero speed/thrust and no weapons/drive. Do not replace the articulated creature with a standard Thargoid ship merely because its subentity weapon uses a Thargoid-laser key.

Body generation selects `ceil(random*4)` (0/1 share the horizontal branch), amplitudes `50+ceil(random*100)` or their negative equivalent, offset `ceil(32*random)-8`, and count `8+ceil(16*random)` body/tail entities. Usually there are 9-24; exactly-zero RNG outputs can produce 8, and amplitudes/offset endpoints also need that boundary retained. The last entity is a tail; all earlier entities use the body role. Preserve the actual formulas rather than only the comments' ranges.

For segment index p, base position is head position minus its forward vector times `275+140*p`; copy head orientation, then add right/up sine offsets. The x sine phase is `absoluteSeconds*pi + p*pi/4`; y uses `(p+offset)*pi/4`. Indices 0/1/2 scale both amplitudes by 0.2/0.4/0.6. Body attacks alert the head. A destroyed/removed segment releases later-index siblings within 5,000 into inert corpse mode, restores their scanner colours and removes animation callbacks. Invalid head also releases a segment. Verify whether `shipSpawned` runs before or after the parent writes the segment's phase/amplitudes; that engine event order materially affects the first three scaling factors.

The AI travels toward its stored position with desired range 7,500, then lurks and scans non-serpent ships every five seconds (ten while travelling). Good/equal odds can trigger attack. Low energy flees to 25,600; a cloaked opponent triggers a 12,800-range retreat; recovery pauses five seconds then checks energy every ten. Preserve engine-supplied odds, targeting, attack and missile-evasion behaviours as separate dependencies.

Required checks: random 0/0.1/0.45/0.9 boundaries, life 3/4, unreachable-system relocation, first launch after reload, newly selected current location, same-head suppression, head removal versus death, all credited killer types, segment non-credit, possible extra score point, severed tails, animation after reload and galaxy change.

## P40 The Collector, 0.4: implemented portion and unfinished continuation

Evidence: `Scripts/thecollector.js`, `Config/missiontext.plist`, `Config/planetinfo.plist`, station definitions and the package changelog. R1 core graph of the published portion; R2 runtime compatibility, ship AI and geometry. It ends with a continuation notice at stage 8. References in rumours to a cat retrieval or volatile cargo are story material, not implemented additional assignments. No credit award is implemented for the first delivered parcel, despite the dialogue's promised 1,000 credits.

At the first mission-screen opportunity after each docking, if stage<2 and random<0.1, show the galaxy hint (stage 1), including outside galaxy 0. Its optional bribe costs 1,000 credits and redirects to stage 2; insufficient cash hides that choice. The bribe is not required to visit the collector directly. Other progression requires galaxy 0. At Rarere's main station, system 119, stage<4 gives the local station rumour (stage 3). Dock the collector's separate station to enter stage 4. Two pairs of conversational answers converge; either acceptance answer advances to stage 5 and records the start time. Refusal leaves stage 4 available for a later offer. The normalized [choice graph](data/oolite-collector-choices.json) records every implemented option/cost/redirect without reproducing dialogue.

At Leritean's main station, system 160, stage 5 or 6: calculate elapsed hours from saved stage-5 time. A truthy start time and hours<63 gives stage 7; exactly 63 or later gives stage 6. Elapsed time displayed is rounded upward to tenths of an hour. No explicit cargo item is added on success. Return to the collector in stage 7 ->8, continuation notice, with no cash increment. Return in stage 6 ->4 permits another accepted attempt with a new stage-5 start time. The stage-6 Leritean check can repeat but does not itself reset the original deadline. There is no implemented rival courier to race or parcel-destruction check.

In stage>3, entering Bibe/system 122 or Bioris/181 spawns `floor(1+3*random)` pirate-role ships within 25,000 of the player, fits injection, sets fuel 7 and targets the player. There is no kill quota. The trap AI initially searches for the player every three seconds and attacks when found; combat, flee, loot and wormhole-follow branches use Oolite's legacy AI methods. These encounters continue even after stage 8 because the guard is >3, not an active-contract-only predicate. The package changes Rarere's sun-distance modifier to 120.

The collector's station is at fixed coordinates (-1219441.8670473576,-1134372.290313594,113154.84710425357). Define A as main-station position plus the unit vector toward the current sun times 1,536,000; S is the fixed collector position; D=unit(A-S). Orient the station toward D and put the gate at S+20,000*D. Buoys use S+20,000*i*D for i=2 through `round(length(A-S)/20000)`. When that count exceeds 500, skip the middle after i=496 to the last few and enable the gate beacon. Place 32 asteroids around A at radius 30,000, 64 at midpoint(A,S) at radius 40,000, and 32 around S at radius 30,000. The station and asteroid populators differ in deterministic status; engine version and sun modifications change the guide line even though S is fixed.

Save stage and the JSON timestamp array in missionVariables. Startup restores stage, updates instructions, then parses the saved times over the temporary array; retain this order when auditing reload. Subpage, first-screen flag and station entity pointer are transient. The script calls `JSON.parse` on the saved times without a try/catch; verify the engine's missing-variable value before assuming a clean first-run path. Catalogue/manifest require Oolite 1.79 while `requires.plist` says 1.77, with separate creation hooks for both. Do not invent later ship-delivery objectives from the two negative-stage `todo` branches or treat the continuation notice as a reward.

Required checks: hint probability, insufficient bribe cash, direct collector visit, every converging/refusal choice, missing/zero start time, elapsed 62.999/63 hours, late retry, stage-7 return without physical cargo, no promised payout, persistent stage-8 ambushes, save/reload in stages 5-7, first-run JSON handling, station recreation and modified-sun geometry.

## P25 Love Cats, 2.0

Evidence: `Scripts/lovecat.js`, `lovecat_asp.js`, `lovecat_escapepod.js`, `lovecat_romeo.js`, `Config/shipdata.plist` and mission text in the [Love Cats package](https://wiki.alioth.net/img_auth.php/a/a9/LoveCats_2.0.oxz). The world-script file name is listed exactly in the manifest. R1 core graph; pilot-unload/event ordering, optional integrations and original engine encounters still need fixtures. All story screens require galaxy index 3 and a main station. The earlier catalogue's Constrictor-completion prerequisite is not in the offer predicate; that flag only enables one ambient patrol branch.

### Story states and consequences

| State and event | Result |
| --- | --- |
| No `wedding` state, dock any system ID >142 | Automatic invitation, STAGE199, mark system 141. No score, cash, Constrictor or equipment gate. |
| Dock 141 in STAGE199 or historical STAGE0 | Offer: YES ->STAGE1, mark 149; NO ->THE_END permanently. Exiting without either choice leaves the invitation pending. |
| STAGE1, dock a system >142 | News ->STAGE2. Dock 149 in either STAGE1/STAGE2 ->STAGE3, mark 114. The cached state means the news screen and second briefing need separate opportunities if the arrival starts in STAGE1. |
| STAGE3, view system-data screen while docked at main station 114 | Clue redirects marker to 83. At 83, system-data clue removes both markers but does not advance state. Neither clue visit is required by the target-spawn predicate. |
| STAGE3, enter 83 or first launch there after loading | Spawn Romeo's `lovecat_carlo` Asp at `wpu(-0.02,0,0.11)`. No duplicate-role suppression. His low-energy event calls abandonShip once. |
| Target hull dies | DESTROYED unless already CAPTURED; remove 83/114 markers. A launched escape pod does not itself set CAPTURED. |
| Target pod scooped by player | CAPTURED, mark 16, update instructions. Pod death sets DESTROYED without a state guard. Its named pilot's unload callback also sets CAPTURED and ORs bounty with 64, irrespective of station; engine callback ordering requires a fixture. |
| Dock 16 in CAPTURED | +10,000 credits, reset bounty to zero, STAGE4, clear instructions/marker. If bounty was zero, briefly set 10 then zero for the Bounty System integration. |
| Dock 16 in DESTROYED | End permanently, +64 bounty, add one tonne narcotics, force launch. Cargo-capacity and launch-related legal processing require engine checks. |
| STAGE4 or historical STAGE98, dock a system >17 | Oola asks for transport: YES ->STAGE99, mark 41; NO ->THE_END. No passenger berth or physical passenger/cargo record is added. |
| STAGE99, dock 41 | +3,209 credits and +6 score; STAGE100, clear instructions/marker. |
| STAGE99, dock 16 or 149 | Betrayal: STAGE100, clear instructions/marker; no additional payment or score. |
| STAGE100, dock a system >42 | Final news, THE_END, delete `wedding_started` and mission handlers. |

The dialogue mentions an eight-day wedding, but these scripts contain no corresponding deadline or 2,000-credit late-return outcome. Do not implement the unused `wedding_notime` text as an executable branch. State variables, rather than passenger inventory, bind the transport objectives.

### Encounter and compatibility profile

STAGE99 arrivals at 41 add four `cat_asp` and two `cat_asp2` at route wp fraction 0.01. Arrivals at 149 add four `cat_asp3` at wp fraction 0.5 only when `conhunt == MISSION_COMPLETE`, regardless of wedding stage. Base hunter Asp: energy 350, recharge 4, speed 400, thrust 50, pitch 1, roll 2, military forward laser, ECM, injectors, shield booster/enhancer, one missile, no pod or scoops. The two cat_asp2 use hardened missiles. Cat_asp3 use route1patrolAI and no cargo; other hunters use pirateAI. Romeo inherits this resource with energy 360, roll 2.1, bounty 50, military forward/beam aft lasers, one hardened missile, escape pod, zero cargo and route2patrolAI. His pod: energy 25, recharge 2, speed 50, thrust 5, pitch/roll 0.5, no missiles/drive, scripted cargo, shuttleAI.

While `wedding_started == YES` and the native nova mission has no state, arrivals reset its novacount to zero. Entering a nova version of systems 16/41/83/114/141/149 sets a news flag: the next main-station opportunity cancels the story except in STAGE3 with affected system 83 or 114, where the script leaves a route-to-83 recovery message. Test the 83 exception even though spawning in a destroyed system may fail. Cataclysm only changes Curruthers' displayed rank here; Library PAD and Vimana HUD are optional presentation integrations.

Persist `wedding` and `wedding_started`; low-energy callback deletion, active Asp/pod IDs and nova flags are transient. Required fixtures: offer without Constrictor, exit choices, direct 83 entry, eight-day narrative without enforced timer, hull/pod callback order, NPC pod scoop/unload, pod destroyed after capture, full hold, wrong hand-in, both Oola outcomes, repeat target spawn, nova recovery/cancellation and reload during capture.

## P38 Taranis, 2.1

Evidence: `Scripts/taranis_one.js`, `taranis_wolfmk2.js`, `Config/shipdata.plist`, custom Wolf AI and mission text in the [Taranis package](https://wiki.alioth.net/img_auth.php/d/dd/Taranis_2.1.oxz). R1 core graph with explicit deadline/event-order quirks; engine AI and station geometry require fixtures.

Offer in galaxy 0/system 141, docked at a non-main station whose name equals `Taranis Corporation HQ`, with no mission state, score >127 and bounty <5. Clean-only is too strict. Conversation choices 1->2->3 display successive briefing pages; choice 4 accepts provisionally and presents a final page, while choice 6 actually starts the mission. Choice 5 sets TAR1_PASSED. Each subsequent witchspace exit has probability 0.05 to clear PASSED for a future reoffer, with no galaxy restriction in that reset handler.

Starting sets `taranis_one_startdate = clock.days`, TAR1_ACTIVE, mark system 111, and pays a 2,000-credit advance. On launch update the displayed remaining time; after a witchspace exit start a zero-delay/two-second repeating timer until `clock.isAdjusting` is false. Let `d = clock.days - startdate`. Display three/two/one days for d=0/1/2. For d>=3 clear the destination marker and show expired instructions, but do not immediately set FAILED. If current system ID is 111 and d<3, the settled-clock callback adds one `taranis-wolf` at `pwm(127112,20303,662546)`. This callback lacks a galaxy guard and duplicate-role test. No target is added merely by starting or launching in system 111; the settled-clock arrival timer is the spawn path.

At any main station in galaxy 0 while ACTIVE and `startdate+2 < clock.days`, present the failure communication; its acknowledgement choice 8 sets FAILED, clears mission fields and removes up to 2,000 credits (`credits>2000` subtracts, otherwise zero). A target's death sets TAR1_DESTROYED without checking killer, galaxy, mission state or current time. At any galaxy-0 main station in DESTROYED, acknowledgement choice 7 completes and adds a further 2,000 credits. An already spawned target can therefore die after expiry and open the success debrief; exact screen/death order matters. No return to HQ or player-only killing blow is required.

Target Wolf Mk II: energy 700, recharge 5, speed 380, thrust 50, pitch 1.2, roll 1.8, four missiles, military laser with three forward mounts, ECM, injection, shield enhancer, scoops, no pod/cargo, bounty zero. `taranisWolfAI.plist` initially heads to witchpoint, then toward planet within 50,000, then `pwm(497300,87000,573900)` within 500, cycling at speed factor 0.8 and ten-second course checks. Attacks/distress/offence can switch it to WolfFightAI; low energy flees to range 25,600 and full energy reattacks. Normal target resources and gun-mount geometry remain necessary for combat parity.

The HQ persists independently of mission completion: galaxy 0/system 141, `pwm(157000,37000,28000)`, deterministic population, only if no existing `taranis` role, orientation computed against the main planet. Completion/failure deletes offer and flight handlers, not the HQ populator. Save the mission state, startdate and remaining-time text; the adjusting-clock timer and active target are transient. Required fixtures: score 127/128, bounty 4/5, provisionally accept then exit before choice 6, decline/reoffer, d=2/3, unadjusted clock, wrong galaxy ID 111, late NPC kill, expiry before/after target death, repeated arrivals and reload during pursuit.

## P41 Thargoid Wars, 5.0

Evidence: `Scripts/thargoidWars.js`, `wombatsThargoidWarsDecoy.js`, `wombatsThargoidWarsSatellite.js`, satellite shipdata and mission text in the [Thargoid Wars package](https://wiki.alioth.net/img_auth.php/6/6a/ThargoidWars_5.0.oxz). The main script labels itself 4.7; package version is 5.0. R1 core encounter/reward graph, R2 engine/transient parity. This is a repeatable encounter family with a cumulative medal progression, not a single accepted campaign or a separate species.

### Activation and generated encounters

Startup initializes state INITIALISE, encounter tally 0, medal cycle 0 and medal NONE, or migrates old `station_attack`. At a main station, initial news activates with probability 0.2 if native Plans is complete OR galaxy index >0, and system ID !=36; state becomes IMPOSSIBLE. Thus later play can operate in galaxy 0 after activation; the old description's blanket G2-G8 restriction is not exact for this profile.

On each ordinary, non-nova arrival after activation, evaluate separate random tests in source order:

| Test | Spawn / consequence |
| --- | --- |
| R<0.06 and state IMPOSSIBLE | State POSSIBLE; a future main-station opportunity schedules the attack announcement. |
| R<0.04 and no CLASS_THARGOID entities | Group of three Thargoids at wp route fraction 0.05; attach reward callbacks. |
| R<0.05 | Decoy offset `0.5*R2`; one decoy at pw fraction `0.88-offset`, switched to dumbAI. A further `R3<5` test is always true for standard Math.random: add three rewarded Thargoids at `0.755-offset`, three police at `0.756-offset`, three traders at `0.754-offset`. This is not a 5% secondary test. |
| R<0.06 and satellite status INFORMED | One spy satellite near absolute (0,0,-20000), radius 5,000. |

Decoy death, whoever kills it, schedules a three-Thargoid group at its position plus radius 2,000 after `15+30*R` seconds. It spawns three cargo pods, but the intended alien-item assignment loops over `cargo.count`, while spawn ordinarily returns an array; verify this API mismatch before claiming the pods contain alien items. Decoy itself lacks the attached tally callback used on the spawned groups.

### Station defence

At a main station with POSSIBLE, unless Cataclysm state is STATION_ATTACK, schedule after `15+45*R` seconds, repeating every twenty until the UI is safe (not mission/report/save screen). The callback stops its timer; if still docked, announce with difficulty `ceil(3*R)` (usually 1-3; exact zero RNG gives 0). NO sets IMPOSSIBLE and decrements tally by one; MAKE_CHOICE redisplays; YES or launch/exit without a resolved choice sets IN_PROGRESS, spawns the attack and launches, restoring the previous bounty to avoid an illegal-cargo launch penalty.

Spawn difficulty Thargoids, twice that many traders, and difficulty-1 police if difficulty>1, all in a 25,000-radius volume around the docked player's position. Store the attacked system ID transiently. On later main-station opportunities in IN_PROGRESS, reject a missing/mismatching stored system; the test treats system ID zero as missing. If no CLASS_THARGOID entities remain within 20,000 of that station, reset IMPOSSIBLE, add current difficulty to tally, clear attackedSystem, and with probability 0.3 schedule another wave through a local POSSIBLE branch. This is a proximity predicate, not proof that the player killed every attacker. If some remain and this is a new docking, warn and reduce difficulty by one down to a minimum 1, affecting the later completion bonus.

### Spy satellite and rewards

When the cached tally is >5 and there is no satellite state, the next main-station screen announces satellites, sets INFORMED and returns before cash reward handling. Satellite spawns with orientation [1,0,1,0] and a one-shot `15+25*R`-second alarm timer. If still alive at expiry, spawn `2+ceil(3*R)` rewarded Thargoids near (0,0,50000) radius 5,000 and `1+round(2*R)` near the satellite radius 15,000. Destruction removes its alarm timer. Satellite death adds one tally if killer.isPlayer; regardless of killer, a 50% test schedules one rewarded Thargoid near (0,0,20000), radius 5,000, after `15+30*R` seconds. Satellite: energy 150, recharge 4, speed 50, thrust 5, pitch 1, roll 2, bounty 100, no missiles, nullAI, CLASS_THARGOID, scanner range 60,000; dish subentity energy 75/recharge 3.

Each reward-attached group member adds one tally only when final killer.isPlayer; it then invokes any original death callback. Player-owned missiles/escorts are not explicitly accepted by this predicate. Ordinary bounties and combat score follow the engine separately. When the tally cached at entry to a main-station opportunity exceeds nine, add 1,000 credits and reset tally to zero, discarding excess. Increment medal cycle; every fifth cash payment resets the cycle and advances NONE->BRONZE->SILVER->GOLD->CRYSTAL. Further fifth payments retain CRYSTAL and show the ordinary reward. A station bonus added during the same opportunity may require the next opportunity because the reward test uses the earlier cached tally.

Optional GalCop Missions integration adds 0.1 reputation to GalCop/local government/navy per rewarded player kill, 0.5 per player satellite kill, and 1 per cash hand-in; medal awards include their time/system/galaxy. Library PAD is optional. Persist tally, medal cycle, medal, activation and satellite state. Attack difficulty/system, all timers and callback-wrapped in-flight entities are transient; loading IN_PROGRESS can cancel the attack due to missing attackedSystem. Required fixtures: activation galaxy/Plans alternatives, independent rolls, zero RNG difficulty, decoy's always-true roll and cargo array, decline below zero tally, launch without choice, leaving the station's radius without kills, repeated docking reduction, NPC/player satellite kills, alarm boundary, excess tally loss, fifth/twentieth payment and active-attack reload.

## P42 Tionisla Reporter, 1.5

Evidence: `Scripts/erehwonMission.js`, `erehwonCamera.js`, `erehwonStation.js`, `reporterConditions.js`, equipment/planet/ship definitions and mission text in the [Tionisla Reporter package](https://wiki.alioth.net/img_auth.php/c/c8/Tionisla_Reporter.oxz). R1 objective and reward graph; camera geometry, populator lifetime and engine cargo/equipment behaviour need fixtures.

### Assignment and hidden destination

Startup initializes START, photo NO, story NO and an empty misjump-hint flag. Offer at Tionisla, galaxy 0/system 124, main station; no score, cash or equipment gate. Accept sets ACCEPTED, grants a portable scripted-only camera, ten exposures and marks Biorle/144. Decline sets DECLINED with actiontime=clock.days+30. The subsequent main-station check uses `actiontime > clock.days`, the reverse of a delayed-news test: a new opportunity during those thirty days ends permanently, while a first return at/after the boundary does not satisfy it. Preserve this as a source quirk.

Docking at main station 144 gives the misjump hint once, without an ACCEPTED-state guard. A standard jump from either Usle/48 or Biorle/144 sets showErehwon=YES. After the hint, when targeting either of those systems, an independent R<0.2 sets scriptedMisjump. The actual custom population is bound to interstellar routes `0 48 144` and `0 144 48`, so an unrelated destination does not become the hidden system merely because the flag was set. Repeated jumps from interstellar space reset the show flag to NO.

Custom population sets 2+floor(4*R) Thargoid groups at the witchpoint, each one ship. If showErehwon=YES add Planet_Erehwon at absolute (-50000,1000,463000), radius field 2500, orientation [1,0,0,0], spin 0.004, seed 1/2/3/4/5/6; add the station if not destroyed at absolute (-50000,4000,413000), radius 1. The populator uses a transient `$populatorRun` guard with no reset in this package: verify repeat visits in the selected engine before asserting that every misjump rebuilds the scene. An optional Interstellar Tweaks handler is temporarily removed and restored after arrival.

The station orients using the vector to the planet and adds a buoy 10,000 along its heading. It has energy 25,000, recharge 100, ECM, two turrets, up to eight hermit-ship defenders, no police, rotation 0.1 and no clearance requirement. Its death saves `erehwonDestroyed=true`; the planet can still exist while the station is absent. Later success epilogues are blocked by this destroyed flag. Model collision radius, docking and turret resources must be supplied for metre-accurate parity.

### Photograph and interview predicates

Each camera activation consumes one exposure, including bad photographs; at count<1 remove camera. It selects the first ship with primaryRole erehwonStation; the array's truthiness overrides the manually selected target even if no station was found. A valid target must have dataKey ErehwonStation. Let R be its collisionRadius and d be centre distance minus R. Range must be strictly `3R < d < 10R`, equivalent to centre distance strictly between 4R and 11R. Alignment requires `angle * d < R`, using the angle between the relevant view direction and station direction. Forward/aft/port/starboard views are supported; external/other views force deviation=2R and fail. Do not substitute a fixed-degree field-of-view tolerance.

A good photo sets photo YES. If story is already YES, it sets SUCCESS and redirects marker to Tionisla. Docking at the station when story NO sets story YES, then checks photo YES and sets SUCCESS in the same screen opportunity. Both actions are required, in either order; no actual saved screenshot file is required, and `takeSnapShot` is only attempted if that optional test-engine function exists.

At Tionisla main station in ACCEPTED, photo NO and exposure count exactly zero, offer retry; damaged camera also offers retry. Accept regrants camera and resets ten exposures, with no fee; decline follows the same reversed delayed-news rule. A damaged/empty camera after a valid photo but before the interview does not meet the empty-camera retry predicate, so preserve the photo/story flags.

### Debrief, epilogues and persistence

At Tionisla main station in SUCCESS, pay 500 credits, remove camera and photo/story/count/hint flags, clear marker/instructions, set EPILOGUE, index 1, next actiontime=clock.days+30. At any galaxy-0 main station with `clock.days > actiontime`, while the hidden station has not been destroyed, issue the next epilogue and schedule thirty more days from the present opportunity (not from the missed deadline):

| Epilogue | Actual reward |
| --- | --- |
| 1 | +50 credits |
| 2 | Set fuel to 7 |
| 3 | Add min(35, cargoSpaceAvailable) tonnes of narcotics |
| 4 | +75 credits |
| 5 | +50 credits, then add another 100 days to the usual 30-day delay |
| 6 | Add 100 gemstone units (grams in Oolite), then FINISHED and delete offer handler |

Epilogue 5's dialogue claims 75, but the code pays 50. Exact deadline equality does not advance an epilogue. A destroyed station stalls epilogues rather than explicitly setting failure. Population/jump handlers remain after FINISHED to preserve the world. Save missionVariables including the misspelled `erehwomMisJumpInfo`, photo/story/count, destroyed flag and epilogue/actiontime. Timers/populator guard and spawned entities are transient. Required fixtures: photo/interview in either order, all four views, exact radius/alignment boundaries, ten wasted shots, damage/retry, natural and scripted misjump in both directions, repeat visit/populator guard, station destroyed before/after success, decline before/at/after thirty days, each epilogue payout and full-hold cargo limits.

## P18 Ionics, 1.3.1

Evidence: `Scripts/ionics_main.js`, its five ship scripts, `Config/planetinfo.plist`, shipdata and ten custom AIs in the [Ionics package](https://wiki.alioth.net/img_auth.php/f/f9/Ionics_1.3.1.oxz). R1 story/counter graph; R2 battle runtime because this package mixes legacy population actions with JavaScript and contains coordinate/role inconsistencies. Do not call the war engine verified from the briefing alone. All ordinary story screens require galaxy index 1. No score gate or overall countdown appears.

### Campaign and allegiance branches

| State and place | Objective / result |
| --- | --- |
| No state, Zaria/251 main station | PRE_STAGE1; Ramaza status RLF_1. |
| PRE_STAGE1, Ramaza/26 main station | Accept RLF job ->STAGE1, mark Zaria; reject ->MISSION_COMPLETE_1, opening the corporate alternative. |
| STAGE1, Zaria main station | +500 credits, STAGE2A, return Ramaza. No sealed physical cargo is added or checked. |
| STAGE2A, Ramaza main station | +500 credits, offer fleet attack: accept ->STAGE3A/mark251, reject ->MISSION_COMPLETE_3A. The state does not change before the offer callback; exiting without a decision can allow the delivery-payment branch again on another opportunity. |
| STAGE3A, Zaria arrival | Spawn the convoy battle below; destroying the mission Funnelweb, by any killer, sets MISSION_SUCCESSFUL. Escort destruction is not a completion quota. |
| MISSION_SUCCESSFUL, Zaria main station | Optional news ->ZARIA_NEWS_2. |
| MISSION_SUCCESSFUL or ZARIA_NEWS_2, Ramaza main station | +15,000 credits, MISSION_COMPLETE_A, clear instructions. Direct return is allowed. |
| MISSION_COMPLETE_A, Zaria main station | ZARIA_NEWS_3, Ramaza status RLF_2; The Link becomes available. |
| ZARIA_NEWS_3, station named The Link Base | Information choice loops; accept delivery ->STAGE5/mark Cevera198; reject ->MISSION_REJECTED_STAGE5, no continuation handler. |
| STAGE5, Cevera198 main station | STAGE6, mark26, retain RLF_2. No physical equipment/cargo predicate. |
| STAGE6, The Link Base | WAR_IN_RAMAZA; government fleet200, Link100, RLF50, government player-kill counter0; Ramaza status RLF_3. |
| Government fleet counter <1, war timer | WAR_IN_RAMAZA_VICTORY, stop timer and switch remaining weapons platforms to nullAI. |
| WAR_IN_RAMAZA_VICTORY, The Link Base | RAMAZA_WAR_OVER, status LIBERATED, bounty0, clear marker/instructions/fleet counters. No explicit final cash award. |
| MISSION_COMPLETE_1, Zaria main station | Corporate offer: accept ->STAGE2B/mark26; reject ->MISSION_COMPLETE_2B. |
| STAGE2B, Ramaza main station | Infiltration conversation ->STAGE3B, return251; no physical cargo/kill requirement. |
| STAGE3B, Zaria main station | +1,500 credits, MISSION_COMPLETE_B, clear instructions. No onward war branch is present for this allegiance. |

### Scripted encounters and population

STAGE2A entry at Ramaza has a 50% chance of one redback at (0,0,1500). STAGE3A entry at Zaria adds a Funnelweb at (0,0,10000), two mission Redbacks at (0,0,9500), four mission Whitetails at (0,0,9250), one RLF leader at (0,0,2000) and four RLF fighters at (0,0,2500), each with 5,000 spawn radius. Redbacks/Whitetails and their escorts join the Funnelweb's group; ordinary police are told to head for the planet. Re-entering STAGE3A can create another convoy; no duplicate-target check. During STAGE5/STAGE6 any arrival in this galaxy has probability 0.75 of four mission Whitetails at (0,0,-1000).

Legacy Ramaza population evaluates independent branches: RLF_1 adds twenty asteroids near `pwm(400000,0,0)` radius20,000 and five RLF vessels there; RLF_2 adds the same plus Link Base and five Link vessels; LIBERATED sets government6/economy5/productivity58978 and retains asteroids/base. A `ramaza_status == WAR_IN_RAMAZA_VICTORY` branch also retains base/asteroids, but JavaScript sets `ionics`, rather than that status variable, to this value; do not assume the branch is reachable. During `ionics == WAR_IN_RAMAZA`, send ordinary ships away, create base/asteroids and one weapons platform at `pwm(200000,0,0)`. Initial government group: five if fleet>5, otherwise one if fleet1-5; Link: three if fleet>3, otherwise one if fleet1-3; RLF: two if fleet>2, otherwise one if fleet1-2. These initial counts differ from JavaScript reinforcement sizes.

### War replenishment, support and source quirks

Arrival in Ramaza during the war, or first launch after loading there when no timer exists, starts a five-second initial/fifteen-second repeating timer. Government and Link each replenish only when both the relevant primary-role count and stored ShipGroup count are zero, up to min(5, remaining fleet); government launches at main station, Link at the valid Link Base. RLF replenishes when no matching primary role exists, up to min(5, remaining). Each faction ship's death decrements its own remaining fleet regardless of killer. Government death also increments the player's government-kill count only if killer.isPlayer, but dereferences a missing killer without a guard; environmental death needs a fixture. Weapons-platform death adds a player kill but does not decrement the government fleet. Fleeing/escape-pod launch changes faction primaryRole to derelict; government/Link also leave their group.

A return to Link Base while the transient display-stats flag is set gives fuel7, fills all empty missile slots with ordinary missiles, clears bounty and displays counters, then clears that flag. At Ramaza main station with >25 government player kills and the flag set, show a warning; the next opportunity force-launches. Each startWar sets the flag again. Running out of allied fleet counters is not an explicit campaign failure; the player can continue while government remains. Leaving the system stops the timer on its next tick without advancing the story or declaring defeat.

The source computes JavaScript battlezone with `Vector3D(200000,0,0).toCoordinateSystem("pwm")` and RLF addition point with `Vector3D(0,200000,200000).toCoordinateSystem("wpm")`, while legacy AI/world positions use those values as coordinates to convert into world space. Preserve the distinction and verify it in the selected engine. `validatePosition` tests against `this.battlezone` but moves a distant ship with bare `battlezone.add(...)`, an undefined identifier in this script; it is called at Link support debrief. Government AI scans primary roles `link_vessel RLF_vessel`, whereas actual faction primary roles include the `ionics_` prefix. These are runtime concerns, not grounds for silently inventing a corrected encounter.

### Combat resource profile and persistence

Mission Funnelweb: energy6000/recharge4, speed320, thrust3.2, pitch0.2/roll0.4, eight missiles, no forward laser/ECM, twelve turret subentities, custom FunnelwebAI. Its death alone finishes the convoy objective. Base Redback: energy480/recharge3, speed280, thrust30, pitch/roll0.95, beam laser, six missiles, four escorts; mission Redback energy520, pitch/roll1, ECM/pod/injection certain, weapon-energy field25. Base Whitetail: energy120/recharge3, speed380, thrust30, pitch/roll1.85, pulse laser, no pod; mission Whitetail has four missiles/ECM and no pod. RLF leader is a Redback variant with six RLF escorts; RLF fighters/escorts have energy90, four missiles and weapon-energy fields10/8. Huntsman-based Link/RLF war vessels each have energy250/recharge3, speed300, thrust30, pitch1/roll2, pulse laser, one missile, ECM/pod/injection. Government role weights are Redback0.25, Whitetail0.75 and CR150 platform0.05; engine selection/role reassignment must preserve this platform variant. CR150: energy2250/recharge5, speed50, thrust2, pitch0.05/roll0.1, beam forward/military aft, ECM, zero missiles, six turret subentities. Link Base has energy10000/recharge5, up to eight defenders and eight turrets. Exact resolved fields and turret transforms are in [expansion combat resources](data/oolite-combat-resources.json).

Save the story/status, remaining faction counters and government kills. Active groups, timer, base reference, battlezone and display-stats are transient. The primary story's terminal states RAMAZA_WAR_OVER, MISSION_COMPLETE_2B and MISSION_COMPLETE_3A remove handlers on startup; other refused/corporate terminal labels remain inert without an onward branch. Required fixtures: both allegiances, all refusal exits, repeated unresolved delivery payment, direct return after NPC Funnelweb kill, duplicate convoys, Link base loss, support/reload, government counter200->0 including NPC kills, escape pods, weapon-platform role selection, undefined-killer callback, coordinate direction mismatch and the undefined battlezone relocation.

## P26 Military Fiasco, historical 2.5.3 and current 3.0

Evidence: both [historical 2.5.3](https://wiki.alioth.net/img_auth.php/d/db/MilitaryFiasco_2.5.3.oxz) and [3.0](https://wiki.alioth.net/img_auth.php/3/36/MilitaryFiasco_3.0.oxz) packages, separately hashed in O07. Inspect `Scripts/militaryFiasco.js`, `smShip.js`, `smCarrier.js`, `smShipSubent.js`, shipdata and custom AIs; 3.0 additionally has `militaryFiasco_conditions.js`. R1 campaign/counter graph for 2.5.3; 3.0 graph is mapped but has a source-established spawn blocker. Neither has a completed runtime parity fixture. These are two profiles of one canonical assignment.

### Offer, objectives and reward

Offer at any main station, any galaxy, in MIL_START/MIL_RESTART, score>1000 and bounty<5. Save the current cumulative stolen-ship killcount as the baseline when showing the offer, before the player accepts; reset progresscount to zero. Four successive YES callbacks navigate the introduction: the first deducts 5 credits and the fourth adds 100 credits and enters MIL_ACTIVE. Accepting the first page alone has not started the hunt. A flight interruption makes callbacks return without accepting if no longer docked.

Only `smShip.js` deaths with a final killer whose isPlayer flag is true increment cumulative killcount and progresscount; player escort/missile ownership is not explicitly accepted. Let K=cumulative killcount minus initial baseline. Main-station debriefs offer these stages, each requiring a YES acknowledgement:

| Current state | Predicate | Next state |
| --- | --- | --- |
| MIL_ACTIVE | K>0 | MIL_STAGE1 |
| MIL_STAGE1 | K>8 | MIL_STAGE2 |
| MIL_STAGE2 | K>19 | MIL_STAGE3, set remaining helper allowance=`round(cumulative killcount/100)+3` |
| MIL_LEVI_DESTROYED | No further kill quota | MIL_COMPLETE, add 100 gold units (kilograms), clear baseline/helper fields and instructions |

The 1/9/20 thresholds use one fixed initial baseline, not an additional 1+9+20 enemies. Stage briefing screens reset progresscount; otherwise >4 progresscount can trigger a status screen and reset it. Destroying the pirate Leviathan by any killer sets MIL_LEVI_DESTROYED, with no current-stage guard; an extant carrier death can override another state. There is no cash completion bonus or unique final-system destination.

NO stores the current state in `military_fiasco_delay`, enters MIL_DELAY and keeps a pending-mission instruction. On an ordinary arrival, random<0.02 plus progresscount>1 restores that state (or MIL_START if absent). NEVER enters MIL_NEVER and clears the baseline; it can still reset to MIL_START on an ordinary arrival with random<0.001 and progresscount>25. In historical 2.5.3, completed missions can restart with random<0.001 and progresscount>10. Version 3.0 adds a saved restartAllowed preference, default false, which must also be true for that completed-mission restart. This changes repeatability and must not be merged into the older profile.

### Encounter generation and target resources

On ordinary arrivals, make separate source-order tests:

| State | Stolen fighter encounter | Friendly Leviathan attempt |
| --- | --- | --- |
| MIL_ACTIVE | R<0.17: one smship at route fraction `0.2+0.5*R2` | R<0.06 |
| MIL_STAGE1 | R<0.26: two smship at `0.3+0.5*R2` | R<0.11 |
| MIL_STAGE2 | R<0.33: three smship at `0.3+0.5*R2` | R<0.11 |
| MIL_STAGE3 | R<0.21: pirate Leviathan at unit(sun.position)*30000, radius5000; add max(1, helper allowance) smship within8000 of it and flag them as helpers | R<0.11 |
| MIL_DELAY | No scripted fighter batch | R<0.06 |
| MIL_NEVER or MIL_COMPLETE | No scripted fighter batch | R<0.035 |

Each friendly carrier attempt additionally requires `system.government > 3*R` and schedules a `0.5+8*R`-second callback; addCarrier only actually spawns outside interstellar space. Interstellar arrival schedules that same callback with probability0.10 and delay`1.5+23.5*R`, then returns; because the callback refuses interstellar space, do not treat this as a guaranteed witchspace friendly-carrier encounter. Delayed arrival into ordinary space before it fires is an event-order edge case.

The smship role selects Basilisk, Hydra, Hydra2 or Rattle. Core hulls respectively: energy380/380/380/350, recharge3.5/3.5/3.2/3.5, speed285/160/140/300, thrust48/20/20/48. All have zero missiles and no hull forward laser; their three/six/eight/four destructible forward laser subentities supply beam weapons with weapon-energy field15. A historical combat profile must reproduce loss of these mounts rather than treating the ship as an ordinary hull-mounted gun. The detailed resource dataset preserves pitch/roll, equipment probabilities and mount transforms. At cumulative killcount>150 each new smship has a 50% chance of raw script fuel70. A low-energy ship with no subentities and no mother has a 5% chance of JUMP_AWAY. Helper deaths reduce helper allowance only for player kills; NPC helper kills still remove ships without that decrement.

Pirate Leviathan inherits the friendly hull: energy2100, recharge4, speed340, thrust3.2, pitch0.15/roll0.5, ECM, no missiles/hull laser, six turrets, one smship escort and up to six defenders. At spawn, spare energy is zero when cumulative killcount<=40, otherwise killcount*10. On being attacked while hull energy < half maximum and reserve>0, add min(500,reserve) energy and consume it. This reserve is distinct from recharge. Its AI patrols witchpoint/planet at speed factor0.6, scans for player every ten seconds, calls troops, and launches defenders according to combat odds. Loss/cloak of target resumes its saved direction. Docking is allowed by the AI, but player launch from this carrier sets fuel0. Friendly fighter scripts correct same-group friendly fire and ensure launch fuel/injection; these are separate from hunt kill credit.

### Revision-specific blocker and persistence

In 3.0, the condition script permits keys leviathan/leviathan-pirate/basilisk/hydra1/hydra2/rattle only while state is MIL_ACTIVE, MIL_DELAY or MIL_NEVER; every other state/key returns false. O08 `Universe.m:canInstantiateShip` and `randomShipKeyForRoleRespectingConditions` establish that false blocks role-based ship creation, including the scripted `system.addShips` paths. Therefore ordinary new hunt ships are refused in MIL_STAGE1/2 and the finale carrier is refused in MIL_STAGE3. The finale subsequently reads `mom.position` from an empty spawn result. Child defender variants inherit the condition_script but their different keys also fall through to false, established by `OOShipRegistry.m:mergeShip`. This is a source-established blocker for the inspected package/engine pair, not an assertion about every historical release. The recovered 2.5.3 shipdata has no conditions or condition_script fields and does not impose this blocker. Preserve both profiles; a repaired 3.0 is an explicit adaptation.

Save state, cumulative/progress/baseline counters, delayed state, helper allowance and 3.0 restart preference. Carrier reserve/direction/mother links, detached gunmount timers and pending encounter timers are transient. Required fixtures: score1000/1001, bounty4/5, partial briefing/5-credit fee, K=0/1/8/9/19/20, NO/NEVER returns, cumulative versus per-run helper scaling, carrier killed by NPC, reserve at40/41 and refill boundary, final gold units, original versus 3.0 spawn conditions, inherited defender conditions, escape/cloak/mount loss, and reload during an active carrier battle.

## Engine findings that qualify these expansion profiles

Source O08 pins eight engine files at the same commit used for the native Oolite mission references. These are source/API checks, not successful playthroughs and not proof that all historical engines behave identically.

- `OOJSClock.m` returns `clock.days = floor(clockTime/86400)`. Taranis's three-day gate counts calendar-day boundaries rather than exactly 72 elapsed hours; a start near the end of a day has less elapsed time. Reporter actiontime/epilogues similarly use whole calendar days.
- `OOJSVector.m` maps fromCoordinateSystem to world coordinates and toCoordinateSystem to legacy coordinates. Ionics' inverse-looking calls are a confirmed direction mismatch against its legacy population/AI use, not two spelling aliases for the same conversion.
- `OOJSShip.m:ShipSpawn` and `ShipEntityScriptMethods.m:spawnShipsWithRole` return an array. Thargoid Wars' cargo.count loop does not use the returned array's length and therefore does not assign its intended alien cargo in this engine profile.
- `Universe.m` applies condition_script before selecting/creating ships by role. `OOShipRegistry.m` merges parent fields with child overrides; condition_script is inherited. These establish the Military Fiasco 3.0 blocker above.

## P09 Deposed, 2.1

Evidence: the [Deposed 2.1 package](https://wiki.alioth.net/img_auth.php/a/aa/Deposed_2.1.oxz), SHA-256 `839bea26f7e2cd1f23a5db9c7cf06984a550510688c1d8205bf8930597dcc07d`; `Scripts/deposed.js`, all three ship scripts, shipdata, missiontext, characters and the factory AI. `Config/world-scripts.plist` registers the JavaScript world script. The included `Config/script_.plist` is a legacy reference, not the registered mission implementation. R1 current source graph with explicit blocked branches; R2 original engine/encounter outcomes and optional Library integration. The package README advertises an unresolved plot and possible sequel: the published final notice is the end of this profile, not proof of an implemented pursuit of Drile.

### Transport and police branches

All ordinary first-part screens require galaxy index 3 and main-station docking. Start with no `deposed` or `deposed_started` and score >1693, exactly 1694, rather than the indexed 1700. Accept ->PRELUDE, `depask=DRILE`, `depbien=OKAY`, `deposed_started=YES`, mark 11. Reject ->NOT_PLAYED and remove mission handlers. No passenger berth, commodity, physical passenger or equipment check appears in this JavaScript graph; an unused berth-warning text is not an enforced prerequisite.

| State and event | Next state and effects |
| --- | --- |
| PRELUDE, main station 11 (Bien) | PART1_1; `depbien=BUGGERED`; store legal category CLEAN when bounty==0, FUGITIVE when bounty>31, otherwise OFFENDER; destination 119. |
| PART1_1, station 119 (Esisraan) | PART1_2; destination 42. No payment of the initially promised 2,500 is implemented here. |
| PART1_2, station 42 (Zadige) | PART1_3; +5,000 credits; clear instructions. |
| PART1_3, elsewhere with distance from system 42 >7 LY and `scrambledPseudoRandomNumber(system.ID)>0.5` | News: CLEAN ->PART1_4; OFFENDER ->PART1_4 and bounty OR 5; FUGITIVE ->PART1_6A and bounty OR 90. |
| PART1_4, `depask=DRILE`, system pseudo-random value<0.3 | Police request. YES ->PART1_5A, mark 197; NO ->PART1_6A, stored category FUGITIVE. Either choice sets `depask=ZSKTHAK`. |
| PART1_5A, next ordinary witchspace exit in G3 | PART1_5. |
| PART1_5, station 197 (Dicebe) | Police interview ->PART1_6A; stored OFFENDER becomes CLEAN; deduct min(credits,5,000), unmark 197. This does not itself reset actual bounty. |
| PART1_6A | Arrival ->6B; station screen ->6C; arrival ->6D; station screen ->6E; arrival ->PART1_6. These are event delays, not elapsed-time timers. |
| PART1_6, station 42 | News ->PART1_8A. There is no new marker directing the player back there. |
| PART1_8A | Four G3 ordinary arrivals: 8B,8C,8D,8E; next main-station screen news ->8EE; three arrivals: 8F,8G,PART2. |
| PART2, `depask=ZSKTHAK`, system ID>149 and score>1823 | Offer new work. YES ->PIRATE1, mark 83, `depask=SPIDERS`; NO ->ABANDONED and cleanup. |

The handler captures `var deposed` at entry, so most state writes do not make later tests run in the same call. The witchspace handler similarly captures the old state and advances only one link of a delay chain per arrival. Preserve this event cadence rather than immediately traversing all matching states.

### Pirate investigations and combat assignments

PIRATE1 advances to PIRATE2 on the next ordinary G3 arrival. In PIRATE2 the police-contact choice is offered only when the stored category is CLEAN. YES displays police instructions; NO changes the category to FUGITIVE. The world script immediately sets `depask=OFFWEGO` and state PIRATE3 outside the callback. No corresponding PIRATE2 advancement exists for a category already FUGITIVE.

At main station 83 (Esarqure), PIRATE3->PIRATE4 on one screen and PIRATE4->PIRATE5 on a later screen. Initialize three widow flags to BLACK, unmark 83 and mark 10 (Edorqu). The main-station inquiry interface supplies clues at systems 10/30/54/95/148/119/34/49/75; the three actual ships spawn at system 30 (Atbitela), not at the marked system 10. Each surviving flag creates its corresponding `deposed-blackwidow1/2/3` at wp route fraction 0.1 on arrival or first post-load population. Every widow death, regardless of killer, sets its own flag DESTROYED. When all three die, mark 83, unmark 10 and update instructions. At a main-station screen with all flags destroyed, PIRATE5->PIRATE7; docking 83 in PIRATE7 pays 9,000 and sets PIRATE8. No additional combat quota is checked.

In PIRATE8, a CLEAN player needs a screen at 83; a FUGITIVE can use any G3 main station. Advance to PIRATE8_1, then eight ordinary arrivals through 8A/8B/8C/8D/8E and, after the 8E news screen changes it to 8EE, 8F/8G/PIRATE9. The news screen is a required interruption to the arrival chain. At a main station with ID<255, PIRATE9->PIRATE10, mark 255 and set `deptaran=ALIVE`. A further screen advances to PIRATE11 for CLEAN players only outside 255, or anywhere for FUGITIVE players. Arrival in 255 creates one Tarantula at wp fraction 0.01 while ALIVE. It has six Peldorian Asp escorts. Any killer of the Tarantula sets DEAD, marks 83 and unmarks 255; escorts need not die. Dock 83 in PIRATE11 with DEAD ->PIRATE12, +5,000; a later screen ->PIRATE13.

PIRATE13 delay: arrival ->13A; station screen ->13B; arrival ->13C; station screen ->13D; arrival ->13E; station screen ->13F; arrival ->PIRATE14. At the next G3 main-station screen, order the factory attack ->PIRATE15, `depdrug=ALIVE`, mark 111. Next screen ->PIRATE16. The CLEAN branch briefly assigns PIRATE11 but is immediately overwritten by PIRATE16 in the same block; it is not a real alternate objective.

Arrival in 111 (Onmaar) while PIRATE16 and ALIVE creates the drug factory at absolute (0,0,-200000) with radius 1000, fifteen generic pirates and twenty asteroids within 10000 of that point. Create a factory-led group and add the pirates to its membership; their individual group fields are deliberately not assigned. Factory damage fires a missile if any remain; ATTACKED AI targets the aggressor and orders group attack. Any factory killer sets DESTROYED, marks 83 and unmarks 111. At the next screen, PIRATE16 with DESTROYED sets PIRATE17 and explicitly refreshes the local cached state; if already at 83, the PIRATE17 debrief can run in that same call, pay 10,000 and set PIRATE18. A later screen ->PIRATE19.

### Final delivery and nova intersection

Two ordinary G3 arrivals advance PIRATE19->19A->PIRATE20. At a main station outside 83 with system pseudo-random value>0.7, the return request sets PIRATE21 and marks 83. Dock 83 ->PIRATE22, +5,000 advance for a galactic drive, unmark 83, mark 138 (Usesri). Next screen ->PIRATE23. If the native nova mission has not started and `deposed_started==YES`, set `novacount=2` and `deposed_started=NOVACHANCE`. At station 138 in PIRATE23, passenger pickup is represented only by state PIRATE24 and instruction/marker changes; no berth check or physical passenger is installed.

Entering galaxy 4 while PIRATE24 marks 70 and sets PIRATE25. Dock 70 (Tetiri) in PIRATE25 pays 5,000 ->PIRATE26 and clears instructions/marker. Next main-station screen ->PIRATE27. Four ordinary G4 arrivals ->27A/27B/27C/PIRATE28; next main-station screen displays news ->PIRATE29. A subsequent G4 main-station screen with pseudo-random value<0.1 ends the published campaign, state MISSION_COMPLETE, removes auxiliary mission fields and handlers. There is no final capture or 5,000-credit information-bounty award: that amount appears in ending news only.

While `deposed_started==YES` and native nova is unset, G3 arrivals reset `novacount=0`, suppressing the native assignment. The final delivery relaxes that suppression. Preserve the following source defects as version-specific branches:

- An initially FUGITIVE passenger carrier bypasses the police request, leaving `depask=DRILE`; PART2 requires ZSKTHAK and stalls. A player who refuses the earlier police request receives ZSKTHAK but remains FUGITIVE, then stalls in PIRATE2 because only CLEAN has an advance branch. Refusing police contact from the CLEAN PIRATE2 screen happens after the advance and can continue.
- The intended nova escape without passenger checks PIRATE23/NOVACHANCE/NOVA_HERO in the new-galaxy handler, then changes `deposed_started` to NOVA_HAPPENED. The later G4 screen that would set PIRATE25 still requires NOVACHANCE. Consequently that inspected branch strands state PIRATE23; a repaired handoff is an adaptation. The ordinary passenger route through PIRATE24 works independently.
- Detection of a prior nova at key systems 11/30/42/43/49/54/75/83/111/119/138/255 uses `missionVariables.nova_deposed_bug == "YES"`, a comparison instead of assignment. It does not set the intended warning. The warning screen, even when the flag is externally present, clears only that flag rather than ending the mission.
- Optional Lib_PAD helpers store an update under the literal key `person` and use an undeclared `rank` in the information helper. With that optional script present they can interrupt callbacks or fail to restore character records; test separately. Lib_PAD is not a required package dependency.

There is no general calendar deadline or explicit escape-pod/departure failure handler. Lost targets are repopulated from their surviving flags on later qualifying arrivals; no per-role duplicate guard appears in `$addShips`. A first mission-screen opportunity after load also invokes population in G3/G4, even before launch. Preserve mission variables, markers and the separation between persistent flag state and transient ships/groups.

### Combat resources and acceptance cases

Bien Interceptor is a Sidewinder template variant: energy 350/recharge 5, speed 320, thrust 25, pitch 1/roll 1.75, military laser, ECM/pod, two missiles and weapon-energy field 30. Once `depbien=BUGGERED`, every arrival in G3/system 11 adds four at wp 0.05. While PIRATE11, every launch from 11 additionally adds six within 10000 of the departure station, with no one-time guard. During PART1_1 or PART1_2 outside 42, choose count=floor(6R); if nonzero add a group at random route fraction, and in PART1_1 add another count ships at wp 0.05.

Black Widow uses its own model over Fer-de-Lance template defaults: energy 500, speed 450, pitch 1.25/roll 2, military forward/pulse aft, ECM/pod/scoops, shield booster and enhancer, four missiles, no injection, raw fuel 60, bounty 250, cargo 20. Below score 2560 remove the shield enhancer; make negative accuracy positive. Tarantula is a Boa Mk II variant: energy 1000/recharge 20, speed 200, thrust 30, pitch 0.25/roll 0.5, Thargoid forward/aft lasers, ECM/pod/scoops/injection, bounty 250, cargo 200, missile capacity 8. Fill its initially empty pylons independently from [ordinary,ordinary,hardened], so hardened probability 1/3 per pylon. Factory: energy 1400/recharge 25, speed 0, thrust 100, pitch/roll 8, no laser, ECM, ten missiles with load time 10, bounty 500 and cargo 900. Resource fields and external-template dependencies are in [combat resources](data/oolite-combat-resources.json).

Required fixtures: score 1693/1694 and 1823/1824; saved legal categories 0/1/31/32; every refusal; all arrival/screen delay links; cached state versus explicit PIRATE17 refresh; widow/target NPC kills; score 2559/2560 shield change; six escorts and eight random pylons; factory group response; repeated launch/loaded population; prior-nova warning typo; normal G4 delivery versus stranded nova escape; optional Lib_PAD errors; payouts 5,000/9,000/5,000/10,000/5,000/5,000 with police recovery; ending notice without an invented sequel.

[P46 Benus escort and Arn prototype](vector-arn-mission-specifications.md) are individually ready with 35 selected callback checks, explicit orbital boarding/medical/sabotage replacements, finite reachable route generation, unique reward/storage and gallery contracts. This bounded packet does not close the other Vector salvage/inspection/Areidis/specialist families.

[P46 Richmans World and flight inspection](vector-salvage-inspection-specifications.md) are now individually ready and delivered: six settlement choices, exact quote/risk/strength rules, scanner approach/compliance/fines, explicit once-only payment and safe custody repairs, 78 selected source callbacks and 20 CCL callbacks. [Shared Vector mechanics](data/vector-services-mechanics.json) pin 87 definitions, 21 AIs, 24 base envelopes and 36 station flag rows; aliases/components are not additional hulls. Original NPC energy inputs require the explicitly borrowed O08 booster/enhancer assembly; native implementation remains separate. Areidis/Specialist station closure is still pending.

[P46 Areidis terminals and Specialist trade](vector-station-specifications.md) complete the recovered Vector objective inventory: 24 scripts accounted for across six retained bounded mission/event families, 17 selected station checks, five identical decrypted messages with no invented continuation, seven independently matched endpoints, source gram-unit market rules and explicit orbital/animation/custody/reward repairs. Missing scanner unlocks, empty/future phone/actor handlers and original walking/cubes remain reference-only. All six profiles have been delivered incrementally with gallery requirements; original-engine parity and native implementation remain separate.

## Rescue Stations1.5.4: first escort family

[Base1 and variants1a/1b](rescue-escort-mission-specifications.md) are ready as three bounded project profiles. Their157 factual definitions,11 selected AIs,16 model envelopes, source/core-role equipment and nine engine readers remain in [mechanics](data/rescue-family1-mechanics.json).52 selected family checks establish callbacks/ordering/source defects;2063 additional source checks cover all2048 station/RNG predicates, eight headquarters and anomaly boundaries. An independently compiled metric checks59264 route candidates and records25 differences from the current Swift floating-half-y formula; preserve the selected source route/group-wormhole semantics. Optional formation/targeting, orbital station identities, terminal cleanup and gallery are specified. Other actual scenarios2/2a/2b,3/3a,4/4a/4b,5/5a and6/6a remain open.

[Scenario2/2a couriers](rescue-courier-mission-specifications.md) now have30 selected callback checks, seven resolved equal-weight core hunter definitions, the dedicated hunter AI, source route scatter/catchup rules and explicit packet/clock/once-only save/gallery contracts. Their source display models do not establish physical cargo tonnage. Scenario2b solar lab and3/3a,4/4a/4b,5/5a,6/6a remain open.

The owner now requests [RRS contract-board support](rrs-contract-board-specifications.md), including headquarters through an explicit project capability. Native HQ no-board evidence is preserved, accepted contracts retain the original station identity, and only individually completed/implemented/safe profiles become live offers. No raw package or research-open solar lab is enabled by this UI extension. The board has separate isolated gallery and save/fit acceptance requirements.

[Scenario2b solar lab](rescue-solar-mission-specifications.md) now closes the third family2 variant with pinned package/engine mechanics, source75credit/+4rep success,80credit refundable paid lease,1400second checkout and14400second deadline. Narrow temperature-band repair and explicit escrow/collector/station/persistence handling replace source exploit/reset behaviours.22 actual source callbacks,15 selected repair/financial cases and45 independent thermal comparisons pass. Other actual scenario3/3a,4/4a/4b,5/5a and6/6a remain open.

[Scenario3/3a recovery](rescue-blackbox-mission-specifications.md) closes two more P30 profiles, with one-tonne special cargo,7172source-ordered minimum-jump routes,311equal-cost alternate-time ties,150asteroids, concealed Sidewinder activation and per-entry assassin waves.44sourcecallbacks and8repairedgatecases pass. Four AIs and11factual definitions/11engine references are pinned; the source ambush plist's missing final member terminator uses a labelled in-memory extraction repair. Remaining P30 scenarios4/4a/4b,5/5a and6/6a stay open.
