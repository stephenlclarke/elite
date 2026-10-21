# Curse of the Black Sunspot

O07 P08, cim's 1.0.2, is an informal Oolite space mission: encounter a pirate leader, inherit a malicious flight-system infection if you kill him, then pay for replacement electronics or retrieve its transmitter. The [author's page](https://wiki.alioth.net/index.php/Curse_of_the_Black_Sunspot) confirms Galaxy 3, Dangerous eligibility and optional integrations. Exact rules below come from the downloaded package's ten scripts, two AIs and configuration files, identified in [package provenance](data/oolite-pack-sources.json). The [24 callback checks](data/black-sunspot-source-fixtures.json) execute original code with a mocked API; they establish selected branches, not original-engine combat parity. No planetside replacement is required.

## States, activation and encounters

Initialize absent COTBS_stage to FUTURE. On witchspace arrival, FUTURE, galaxyNumber 2, score >=512 and random <0.2 advance PRESENT. Equality at 0.2 does not activate. There is no employer or acceptance screen. The shipyard ending writes COMPLETED while the early exit writes COMPLETE; startup only bypasses initialization for COMPLETE. Normalize terminal states in the project while preserving their distinct outcome IDs.

While PRESENT in Galaxy 3, systems 1,14,21,72,103,222 receive extra pirates. Set a budget to floor(existing primary-role pirate count *0.25 + random *0.25). Add groups of 2..4 until the budget is exhausted, subtracting the whole group even when it overshoots. Each group appears at mainPlanet.position multiplied by 0.1+0.8*random. All pirate accuracy increases by random*7, bounty is bitwise-ORed with floor(random*64), and 80% copy the forward gun to the rear. Within that branch, 50% upgrade a forward pulse gun to beam; subentity guns have their own conversion checks. Preserve draw order when reproducing the selected source profile.

Enanen, system 72, spawns the leader halfway along the planet vector, radius 10,000. The Python Adversarial has base energy 700, recharge 4.5, speed 270, front/aft military and side beam guns, accuracy 9, ECM and shield booster. The core Python supplies two missile slots, with hardened missiles selected. NPC shield upgrades affect energy under O08 rather than creating player shield bars. Four unique escorts are selected in order by the condition-script counter: two Asps with military forward/beam aft, ECM/injectors/shield boosters; a Cobra III with energy 256, recharge 6.5, speed 350, four hardened missiles and military/beam facings; a beam-armed Sidewinder. Their actual inherited fields remain in [expansion resources](data/oolite-expansion-resources.json); apply the O08 reader rules, not only these headline overrides. Leader bounty becomes 255; escort bounty is 64..127. Escort loss counts 2,3,4 produce different warnings.

Only death attributed exactly to player.ship advances DESTROYED, delay 1 calendar day, substage UNKNOWN. Any other killer ends COMPLETE and cleans up. Both paths drop 20..29 scripted loot pods. Each pod holds 20..59 units, gold by default, independently replaced by gems with probability 0.5 and then platinum with probability 0.25: final probabilities are 37.5% gold,37.5% gems,25% platinum. Gold/platinum use native kg and gems native g; these are not that many tonnes. Pod velocity has magnitude 30. No separate employer payment is awarded.

## Infection and travel

Positive COTBS_delay decrements on dayChanged. Buying a ship or launching an escape pod adds three days and sets a later taunt flag. Purchasing EQ_COTBS_RESTORE costs 1,000 credits and resets delay to three days. Equipment TL index is 8; conditions require DESTROYED, delay <3 and substage other than UNKNOWN/THATSODD/NEEDTL9. The service item is removed immediately. Ship changes postpone rather than cure the infection.

On launch or witchspace exit with DESTROYED and delay <=0, create a timer starting after 30+random*10 seconds, repeating every 80+random*40 seconds. Working EQ_DCN or EQ_REPAIRBOTS_CONTROLLER divides the repeat interval by three. The regular damage callback skips docking and positive delay. Leaving a system stops the main curse and jump-interruption timers; original cleanup is incomplete and needs the repairs below.

| Random interval | Effect |
| --- | --- |
| [0,0.33) | Repeat takeInternalDamage until it succeeds; sound and possible recognition. |
| [0.33,0.50) | Camera disturbance; effect parameter rises from -1 at delta/7 until >1, so removal is strictly after 14 seconds. |
| [0.50,0.66) | Hide HUD; restore after random*15 seconds. |
| [0.66,0.70) | Attempt fireMissile; when firing fails, fall through to shield drain. Successful firing consumes a real round. |
| [0.70,0.75), plus failed missile branch | Drain each shield at 32 units/second until both <1 or the ship docks. |
| [0.75,0.90) | Taunt only. |
| [0.90,1), fuel >0 | Set fuelLeakRate to 1. O08 drains one native tenth-LY unit/second, approximately 0.1 LY/second, with accumulator phase. |

Most damage branches call recognition: UNKNOWN becomes THATSODD with probability 0.25. Galactic jump countdown damages the galactic drive even during the grace period. A normal jump outside system 72, with expired delay and a target farther from 72 than the current system, schedules interruption at countdownSeconds-0.1. Compute the shortest route toward 72 and its next system; if the player can afford that hop, spawn the source misjumper ahead by collisionRadius+100, open its wormhole, deduct that hop's fuel, place the player at it with zero velocity and force recognition. The project must implement the resulting redirected jump atomically, without retaining the original destination or double fuel deduction. No route/insufficient fuel leaves the original countdown intact.

During an expired infection, red alert spawns 2..4 ghost ships within radius 10,000; leaving red alert removes them. A dead ghost replaces itself while red alert remains. They use an invisible physical ship, six possible visual skins, energy 1, speed 400, roll/pitch 2, rock scan class and no kill credit. Their AI targets the player, intercepts to range 200 and explodes when close or when the target is lost. They are malicious projections, not a newly verified alien species.

Docked GUI changes also trigger source sabotage: random <0.03 buys narcotics repeatedly while hold, stock and credits allow, requiring cash strictly greater than price/10; [0.03,0.06) removes missiles through EQ_MISSILE_REMOVAL and deducts 20 credits, potentially producing negative cash. These are once-per-event source effects, not periodically rerolled while a screen remains open. Apply the personal-equipment storage policy to the repaired project variant and clearly distinguish stored rounds from destroyed/expended quest items.

## Transmitter and asteroid

In Galaxy 3/system 72 after FUTURE, compute planar = direction(sun.position), normal = planar cross direction(planet.position). The sunspot is sun.position minus direction(0.5*planar+0.87*normal)*sun.radius*0.999. The asteroid lies along that outward spot direction at ten sun radii from the sun. Handle a degenerate vector with a stable perpendicular in the project; this is a numerical repair.

Spawn the asteroid and four Asp guards while PRESENT, or DESTROYED unless substage is SCOOPED or SEARCHED. The rock has energy 20,000, no recharge or movement, four frangible turrets, each energy 250/recharge 3. A transmitter, energy 25/no recharge, sits at rock position +forward*632-up*240+right*240. It is CLASS_CARGO/CARGO_SCRIPTED_ITEM with null AI. Beyond distance 30,000 the script resets it to this offset. Scrape damage is undone and velocity reset. The four guards have military/beam guns, ECM/injectors/shield boosters, accuracy 8, base bounty 20 bitwise-ORed with a random 0..63.

The rock AI checks every five seconds. With a transmitter and DESTROYED, distance <51,200 and random <0.3 call forced curse damage without the grace/docking guard. Otherwise expired delay and random <0.02 attempt regular curse damage and increment triangulation; after eleven such increments the transmitter receives its beacon. A skipped regular damage application can still increment this source counter.

Once all four turrets are gone, self-destruct increments once per five-second check while the transmitter remains, three times when it is gone. At count exactly 15, dealEnergyDamage(255,5000,0), then explode: nominally 75 or 25 seconds from the relevant first tick. Rock destruction destroys a remaining transmitter and produces fifteen asteroid fragments that immediately explode. Scoop the transmitter before destruction rather than treating turret removal as retrieval.

Player scoop while DESTROYED sets SCOOPED; NPC scoop or transmitter destruction sets SEARCHED. O08 requires a working scoop and one free hold slot even for this scripted item; the callback records quest custody rather than a normal tonne of commodity. Preserve that custody across hull changes and saves. In the original, choosing to search again from SEARCHED sets PERSIST but the next arrival resets SEARCHED, which suppresses rock spawning. Explicit project repair: respawn one transmitter encounter on the next Enanen visit, bind it to the existing mission ID and never grant duplicate custody.

## Station diagnosis and endings

Only docking at the system main station triggers diagnosis. Tech index <8 turns THATSODD into NEEDTL9; indices 8..11 turn THATSODD/NEEDTL9 into NEEDTL13. Tech >=12 offers the final choice for THATSODD/NEEDTL9/NEEDTL13/SEARCHED, with cost floor(player.ship.price/5). O08's JS price reads the raw commander-dictionary valuation in credits, including applicable equipment; it is not the discounted, serviced cash trade-in quote and not decicredits despite a misleading JS comment.

Choice 01_TRANS begins SEARCHING and marks systems 72,22,79. From SEARCHED it instead sets PERSIST. Choice 02_CLEANUP ends COMPLETED and charges the calculated cost. **Only when cost exceeds available credits**, cap the charge to all available cash, add two days of game time and remove the naval energy unit, naval shield booster and shield booster. With sufficient cash there is no scripted service-time addition or such removal. The project stores removed personal equipment rather than deleting it. Original callback treats every non-01_TRANS value, including cancel, as payment; repair cancel to leave state unchanged.

At tech >=12, SCOOPED instead awards 2,500 credits, adds five hours and ends COMPLETED. Any qualifying main station works; Cedile/Bixein are suggested destinations, not the sole allowed IDs. Transfer transmitter custody, payment and terminal flag once in one transaction.

## Repairs and acceptance

Invoke the announcement-template factory rather than passing its function object as screen parameters. The guard's unqualified ship reference resolves its script-object property under O08; it is not established as a source error. Use a local transmitter-position variable. Normalize terminal-state checks and stop/remove every owned main/sub/jump timer, frame callback, ghost/effect and beacon on resolution; restore HUD and clear curse-created fuel leakage. Save remaining timers, generated encounter identities, turret destruction, transmitter custody/triangulation and branch choice. Rebuild them without rerolling on reload.

The original internal-damage loop has no retry bound. O08 can return false for unsuccessful equipment/cargo selections and only applies cosmetic wear when the trade-in factor exceeds 75 and its bit test succeeds. The fixture demonstrates a hang under an always-false damage API, not a measured original-game crash. Project repair: choose directly from eligible damageable cargo/equipment/wear outcomes; if none exist, perform a taunt-only tick. This avoids inventing mandatory destruction of intrinsically required docking/drive equipment.

Verify activation threshold/RNG boundaries, all six outland populations, player/NPC leader death, all four escort identities, every curse interval, missile-success/failure fallthrough, service availability, day rollover, galactic/redirected jump fuel, ghost lifecycle, full/zero holds, player/NPC/destruction transmitter paths, retry encounter persistence, each station tech boundary, both payment cash branches, Back and once-only reward. Run encounter outcomes against project physics separately; original-Oolite timing/assets parity remains unverified.
