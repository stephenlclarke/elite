# Illegal Goods Tweak assignments

O07 P17, package 2.3.1, adds station customs/rescue services, a generated gratitude journey, four reward variants and a slaver-base follow-up. Scripts/illegal_goods_missions.js establishes the graph; illegal_goods_tweak.js creates rescued-person hooks and station penalties; slaverbase.js and ig_legal_hack.js supply target/outfitting effects. All are pinned in [package provenance](data/oolite-pack-sources.json), with selected callback results in [secondary source checks](data/secondary-oxp-source-fixtures.json). These are space-flight and station-service assignments. Original station visits are handoff dialogue; no planetside gameplay is required.

## Rescue service and offer generation

At a qualifying GalCop station, handing over unpermitted rescued people removes their manifest quantities and pays five credits per unit; narcotics/firearms handed over under the broader customs variant pay one per unit. Permitted New Cargoes entries are excluded from confiscation/reward. Multi-bay/Hypercargo compatibility enumerates the appropriate holds. The project uses distinct person/cargo custody IDs, not a commodity-copy operation. Any personal equipment removed by a station service follows persistent surplus storage rules.

For each rescued-person unit, until the first success, roll random <0.1. If there is no pending mission, success records a pending contact, rescue system/date and launch day currentDay+7+floor(random*8), seven to fourteen days later. At a main-station screen opportunity with that day reached and no active assignment, roll 40% special setup or 60% standard setup. A special setup first creates a valid standard destination, then selects uniformly among four variants. Insurance/legal-hack variants fall back to standard if that reward is already working.

Choose a system from systemsInRange(35), retrying at most 100 times. Reject no route, post-nova or direct distance <7 LY; exactly seven LY is allowed despite a comment saying within seven. A valid destination yields reward 500+floor(route.distance/7)*250 credits. Generate two-part contact name and rescuee identity, mark the destination and freeze reward/route. The source leaves potentialmissionsystem undefined when the candidate array is empty, then attempts to read its system info; explicit project repair makes empty/no-valid sets a clean no-offer result. Pending offer remains available for a later valid location.

There is no accepted-assignment deadline in this profile. Changing galaxy clears pending/active assignments and instructions; project cleanup must also remove all old markers and encounters. Do not invent an expiry for the gratitude journey.

## Destination outcomes

Only the destination system's main-station screen triggers completion. Standard pays the frozen reward and adds 43,200 game seconds, then clears the assignment. Special outcomes are:

| Variant | Outcome |
| --- | --- |
| special1 | Rescued contact is the indexed son. Accept the ship visit: full reward, twelve hours and one Trumble. Decline: half the reward, no scripted time addition or Trumble. Project Back leaves choice pending. |
| special2 | Award one EQ_IG_INSURANCE policy; no standard cash reward is added. It refunds one maintenance overhaul and is consumed. |
| special3 | Award one EQ_IG_LEGAL_HACK chip; no standard cash reward. Activation with positive bounty clears it and consumes the chip; already clean retains it. Bounty System integration first exposes hidden offences when necessary. |
| special4 | Pay the standard reward, then offer the slaver-base follow-up. Accept sets special5 and rescued count zero; decline closes the assignment. |
| special5 | After base destruction, allow more rescues or final settlement. Final payout is 1,000+50*rescuedCount credits, then close. No mandatory positive rescued quota is enforced by source. |

The special4 payment occurs before its choice resolves. Calling the screen opportunity again pays again in the original; the fixture reproduces this. Project repair assigns a separate once-only payment ID before displaying the follow-up. Every item/reward/custody transfer and stage change is atomic. Special1 cancel must not silently select the half-pay branch.

## Slaver base encounter

The base exists in the target system whenever the assignment is special4 or special5 and the base is not yet destroyed, even before follow-up acceptance. Position is Vector3D(0,0,1.2+random*0.2).fromCoordinateSystem(psu), beyond the sun. Spawn three pirate guards within player scanner range and eight asteroids there. The rock-hermit-derived ig_slaver_base has energy 2,000, recharge 10, heat insulation 5, bounty 2,000, no missiles/front laser and up to ten pirate defense ships; all dictionary/AI values remain in [expansion resources](data/oolite-expansion-resources.json). O08 does not inherit is_template from the parent; the child is spawnable. The earlier simple dictionary merge retained that template flag incorrectly; the resource extraction now follows OOShipRegistry.mergeShip for non-inherited metadata and alias precedence.

The waiting guards are put into nullAI and should awaken when the player comes within twice scanner range, checked every twenty seconds. Source stores `_slaverBase` but reads `_sb` and immediately stops its timer. This is a genuine field-name mismatch; repair the callback to use the stored base and its position, and ignore destroyed guards. Other global names matching script-object properties are valid O08 scope access, not automatically defects.

Base death by any killer sets ig_slaverbasedestroyed and schedules a news item after five days. The mission records rescued manifest units handed over in the destination after destruction; source does not establish they came from that base. Project repair ties the special rescue bonus to unique rescued-person custody and prevents reacquisition/repeated handoff credit. The source's slaver-market generator remains a separate station service; do not count its commodities as identified captives without that adapter.

## Undocumented-release penalty assignments

Manual release of rescued people into a station population records system, count and adjustedSeconds. The first release produces a warning after strictly more than two days. Later release records are processed at docking: after >2 days, set their displayed payment deadline to now+7 days and issue an instruction to return to that system's main station. A return charges min(availableCredits,(10+floor(random*15))*releasedCount) and clears it. Source draws a new fine at payment, so it can differ from the displayed amount; project repair freezes the fine when the obligation is created.

The source overdue check is (now-storedDeadline)/86400 >7, which actually waits another seven days after the displayed deadline, not seven days from issue. A late return is tested before overdue penalty and can still pay. Explicit project repair: enforce the displayed seven-day deadline, with exactly-at-deadline payment allowed, otherwise add 40 bounty once and close. Record this departure from source arithmetic. Galactic travel clears these records; preserve that selected outcome rather than carrying stale system markers between galaxies.

## Persistence and validation

Persist rescue counts/identities, pending contact/date, generated target/route/reward, active variant, both payment IDs, consumed policy/chip IDs, base/guard/debris condition, news deadline and each manual-release obligation. Refund only the documented overhaul cost rather than restoring an arbitrary old whole-credit balance. Ordinary engine bounties for the base/pirates remain distinct from mission payments.

Verify 0/1/many rescued units, no candidates, no route, distance exactly seven, launch day boundary, all four selections/fallbacks, repeat screen before/after choice, Back, galaxy travel, zero/many final rescues, NPC base destruction, guard activation, once-only news, negative/no available cash, displayed/actual fine deadline and hull changes with policies/quest cargo. The source callback fixtures cover selected reward and repeated-payment paths; full rescue/customs integrations and combat outcomes remain explicit implementation checks.
