# Elite Dangerous Operations: bounded project variants

**Archived and excluded from implementation by owner instruction on13 October2026. See [active scope](../implementation-scope.md). Ship data may remain available separately.**

The owner authorized necessary labelled mission-parameter estimates on13 October2026. These [seven complete project variants](data/operations-project-profiles.json) use the official identities and observed objectives in [Operations evidence](operations-evidence.md). They fill26 stages with deterministic rules, NPC fits, map conventions, timers, counts, heat/power handling, success/failure, extraction, rewards and persistence. This is enough to implement the specified adaptations. It does not establish Frontier server parity, every difficulty distribution or exact native maps.

D24 adds a first-hand23 September2026 account of Under Siege: ship combat, SRV/Maverick anti-air turret disabling, ground combat and a final capital heat-relay attack. It supports more than the previously available objective name. The exact phase gates, capital class, target counts and optional-objective effect remain unknown. The project explicitly selects a blockade -> settlement -> capital -> extraction graph. Its numerical values and ordering details are estimates, not a claimed complete historical run.

## Selected Easy solo profile

| Mission | Explicit project stage sequence | Reported values retained | Necessary estimates |
| --- | --- | --- | --- |
| D03 Terminal Prosecution | Pirate wave1 -> wave9 -> general with2 escorts -> Runner extraction | One D19 run's1 then9 opponents | General hull/loadout, escort count, spawn geometry, extraction timing, reward and scaling. |
| D04 Tactical Takedown | Command download -> install2 regulators and breakers A/B ->4 installation defenders -> general with2 escorts -> extraction | Download described as almost five minutes | Adopt300 seconds; exact count/puzzle, interruption, guards, battle population and payout. |
| D05 Firestorm Rescue | Open2 clamps with recon limpets -> rescue10 people while managing heat -> extraction | Clamps/recon, heat management and safe-unload objective | Quota, durations, four one-use vents, heat start10/growth.15 per second/failure100, reinforcement cap and reward. |
| D06 Rapid Response | Rescue20 people -> extraction within original deadline | Reported25-minute limit adopted as1,500 seconds | Timer begins at rescue entry; quota, population, loading/unloading and extraction rules. |
| D07 Reclamation Point | Clear4 approach ships -> deck1 quota20 -> deck2 quota20 ->6 departure ships -> extraction | Reported15-minute decks adopted as900 seconds each | Separate timer origin, finite quota with replacements/cap5, exact populations and reward. Conflicting source reports retained. |
| D08 Biohazard Takedown | 60-second records download ->2 engineering researchers ->2 habitat researchers -> hostile extraction | Reported one-minute download adopted | Target/guard counts, interruption, Runner delay, launch/boarding and reward. |
| D09 Under Siege | Clear4 blockade ships -> settlement quota20 with optional4 AA disables ->6 capital heat relays -> extraction | D21 blockade objective and D24 combined-arms/heat-relay observation | Target counts/class/geometry, phase gates, guards, timers, turret values and reward. |

Only Easy/Hard are offered in these project variants. Solo to four participants is supported. Estimated population scaling is ceil(base*(1+.5*(players-1))*difficultyFactor), with Hard count factor1.5, enemy energy/damage factor1.25 and positive objective deadline factor.8. Do not scale people, regulators, relays, interaction/download durations or stage ordering. The source does not supply these scaling equations; they are visible project choices.

## Closed runtime rules

A docked Operations board creates one saved instance UUID and seed. Refusal leaves no instance. Stage entry creates its authored objective IDs once. Waves advance when all designated prior enemies are dead; a quota counts unique hostile IDs. Stop replacements at quota and make surplus attackers retreat. Persist stage, spawned/dead IDs, shared counters, remaining timers, RNG state, passenger identities, heat, used vents, installed regulators/breaker progress, relay IDs and reward transaction.

Deadlines use remaining simulation seconds; pause/save suspends them. Failure occurs at elapsed >=duration, processed before a simultaneous success. Downloads pause out of range and resume. Wrong breaker order clears breaker progress but leaves installed regulators. Heat runs during access/rescue and stops only after all passengers are safely unloaded; reaching100 before that fails. The four vents each cool15 after a five-second interaction, once per instance. These exact boundary/interruption choices are estimates.

Passengers occupy real berths and retain unique identities. Count a rescue only after unloading at the rescue vessel, never on pickup. Do not put people in surplus-equipment storage. A hull change must preserve them and fit their berths or be blocked. A participant disconnect returns their carried quest people to the pickup pool under the explicit project reconnect policy. Lost/dead passengers fail the instance; they are not silently replaced.

The Runner arrives after the configured15 or30 seconds. Success needs every connected participant boarded; disconnected participants are removed from the quorum. Player death respawns at the Runner after15 seconds while objective progress/time continue, using the instance's equipment restoration policy. Abandonment fails the instance, removes only its quest items/passengers and restores stored personal equipment. A fresh retry uses a new UUID/seed. Rewards are fixed common-project credits once per success:5,000+1,000 per authored stage. These are estimates for this project's economy; no native ED merit/material payout is claimed.

## Combat and maps

Ship NPC roles name common project hull profiles and lasers: Viper fighter with beam/one missile, Python heavy with military/two missiles and Anaconda boss with military/four missiles. These are estimated operation fits. Use their explicitly labelled flight/defence values and the O08 laser damage/range/energy/heat/cadence readers. Preserve native D23 outfitting data independently; these variants do not approximate the entire ED engineering/pip system.

Ground actors have explicit estimated health/shields, movement, weapon damage/cadence/magazine/reload/range and AI in the dataset. Use floor-valid navigation, cover, visibility and seeded hit sampling. The player uses controlled aim. No actors may spawn underground; a stranded target must be relocated to the nearest valid authored spawn rather than causing early success. The mission capital ignores ordinary root-hull damage; only its six unique relay targets trigger retreat. This belongs to the mission instance and does not make the corresponding player refit invulnerable.

All coordinates are authored project layouts, with a fixed Runner/objective separation and120m ground decks. They are not measured native ED locations. The dataset specifies local objective/spawn positions and provisional relay layout. The implementation needs ship combat, boarding/on-foot interactions, NPC navigation and rescue inventory support; marking these research profiles complete does not claim those game systems already exist.

## Verification boundary

Validate every stage and full mission in Easy/Hard for1/2/4 participants; shared kill IDs; exact deadline equality; interrupted/reloaded downloads; heat/vent persistence; two regulator identities/wrong switch order; passenger pickup versus unload/full cabin/disconnect; quota-cap termination; optional AA objectives; every relay identity; extraction quorum; and once-only rewards across reload/reconnect. All stage links resolve in the saved dataset. No implemented game simulation or native ED outcome fixture has yet exercised these adapted profiles.
