# Elite Dangerous Operations evidence

**Archived and excluded from implementation by owner instruction on13 October2026. See [active scope](../implementation-scope.md). Ship data may remain available separately.**

This supplement separates Frontier's published behaviour from player observations. It supplies useful stage graphs, but not verified server scripts, exact scene layouts, every difficulty profile or complete wave/payout formulae. It therefore does not close the full replication requirement.

## Official release boundaries

D20, Frontier's Operations release notes, lists six launch scenarios: Terminal Prosecution, Tactical Takedown, Firestorm Rescue, Rapid Response, Reclamation Point and Biohazard Takedown. D21, the 2 September 2026 Rhino update, adds Under Siege. Earlier promotional names such as Counter Attack and Burning Rescue must not be counted as extra released missions without proof of a distinct scenario. The April preview and release notes are different snapshots.

The release supports a lone commander or a squad, with optional matchmaking. Transport uses the Operation Runner. The July 9 update explicitly records reward/inventory problems and later restoration; absence of a visible payout in an early recording is not proof of an intended zero reward. The September notes list premature Under Siege completion as a known issue and fix Reclamation docking denial after accidental fire. These are version-specific bugs, not universal success predicates. [D20-D22]

## Observed stage sequences

D19 is CmdrJonen's first-hand report and replies from other players. Numbers below are observations, not all-difficulty constants. The post distinguishes completed, attempted and second-hand stages; preserve that distinction.

| Mission | Observed sequence | Unresolved checks |
| --- | --- | --- |
| D03 Terminal Prosecution | Ship encounter -> possible reinforcement phase -> general and escorts -> general dies, escorts depart, Runner arrives. One run reports 1 then 9 opponents. | Branch-selection rule, exact wave pools, general loadout and difficulty scaling. |
| D04 Tactical Takedown | Land under fire -> command-centre download, almost five minutes -> recover regulators/power engineering -> attack installation ships -> general fight. | Exact download duration, regulator count/puzzle, interruption/reset and fleet thresholds. |
| D05 Firestorm Rescue | Open station access with recon limpets -> ferry passengers while reducing heat -> secure every hostage on rescue ship before heat fills. | Passenger quota, heat equation, rescue-ship services and failure boundary. |
| D06 Rapid Response | Ferry personnel from planetary port to rescue vessel while hostile pressure grows; a 25-minute limit is reported. | Difficulty-specific quota, timer start, reinforcement cadence and final extraction. |
| D07 Reclamation Point | Clear surrounding ships -> clear two decks under timers -> further ship battle. Reports mention 15-minute decks. | Reports conflict on finite enemies versus replenishment until a quota/progress bar fills. |
| D08 Biohazard Takedown | Land under fire -> briefing-room download, one minute -> researchers on engineering/habitat decks -> launch and reach Runner under fire. | Exact targets per deck, security respawn limits, door access and extraction trigger. |
| D09 Under Siege | D21 official blockade objective; D24 first-hand report adds optional SRV/Maverick AA disabling, ground combat and final capital heat relays. | Exact gates/order, capital class, counts, timing, optional effects and premature-completion bug. |

## Replication evidence still needed

For each difficulty and participation mode, retain a full successful recording and failed-stage retry, client build, squad size, objective text, timestamps, enemy identities, ship/loadout choices and reward screen. Measure download interruption and restart; regulator recovery and breaker order; objective-count sharing; player death and Runner redeployment; dock/undock services; leave/rejoin; final boarding; server disconnect and save persistence. Observe a timer at equality rather than assuming a printed minute label specifies the actual boundary.

For Reclamation, first distinguish initial waves, replacement waves, quota completion and last-enemy cleanup; the contradictory reports can describe different phases or revisions. Do not resolve the disagreement by inventing a single wave count. For rescue, distinguish people aboard the player's ship from people safely unloaded. Under Siege requires its own complete run, not a copy of an earlier scenario.

Readiness: D03-D08 have R2 observed sequences and R3 exact simulation parity; D09 remains R3. A new game can use the sequences as an explicitly adapted design, but a claim of faithful reproduction still needs the measurements above.

## Later evidence and estimated project variants

D24 is a [23 September2026 first-hand Under Siege account](https://www.reddit.com/r/EliteDangerous/comments/1wo2yzr/under_siege/). It identifies combined ship/ground play, optional AA disabling using a SRV/Maverick role and a capital heat-relay finale. This raises sequence knowledge beyond an objective-only discovery; it does not measure exact phase boundaries, enemy counts or all difficulties. Later comments also report stranded underground enemies.

The owner's necessary-estimate authorization now supports [seven bounded project variants](operations-project-specifications.md), with26 closed stages and individually labelled missing parameters. Those are implementable adaptation designs, while the historical/server fidelity gaps above remain. Under Siege's selected phase ordering is explicitly a reconstruction from official objectives and that first-hand account.
