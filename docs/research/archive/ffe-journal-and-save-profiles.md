# First Encounters journal and saved mission profiles

**Archived and excluded from implementation by owner instruction on13 October2026. See [active scope](../implementation-scope.md). Ship data may remain available separately.**

Source S43 supplies the recovered journal archive and six mission start saves. S39 supplies the JJFFE interpreter and serialization format; S44 supplies an independent save decoder. These profiles establish specific dates, stored states and journal dependencies. They do not establish successful playthroughs or unchanged behaviour in every DOS patch.

## Provenance and validation

The [reference manifest](data/ffe-reference-sources.json) records seven archive URLs, archive hashes and all fourteen inspected member hashes. Downloads were found on [Life on the Frontier](https://lotf.co.uk/download) on 13 October 2026. The repository contains factual metadata and decoded numerical state, not the original game files, saves or journal prose.

`firstenc/game/MISSION.DAT` is 779,951 bytes. S39 `ffedat.asm`, DATA_002292/002293, supplies 672 increasing offsets followed by a zero sentinel: the first is 1 and the last is exactly 779,951. They delimit 671 article slots, including an empty slot; that is not a mission count. All complete four-byte groups decode and re-encode identically using FUNC_000078's bit permutation. This is strong evidence that the recovered data fits the pinned source table. It does not identify the executable revision supplied with the archive or prove another language edition uses identical offsets.

[Journal index](data/ffe-journal-index.json) retains every slot's boundaries, lengths, encoded/decoded hashes and template marker families. It also binds 274 script journal operations to their script, phase, function, source line and byte offset. Markers are substitution instructions, not literal destinations: FUNC_000076 supplies generated names, systems, dates and other variable values. Original prose and unexpanded headlines are excluded.

All six saves passed the iterative-XOR checksum. Their journal sections, 71 mission globals, per-definition static arrays, 150 instance records and active local arrays consume exactly the bytes before the scrambled header. An independent build of S44's original `unmangle.c` agrees with the separate inspection decoder on all thirty decompressed blocks. [Scenario state](data/ffe-scenario-state.json) preserves hashes, raw locals, globals, journal records and active object names/seeds. Old pointer values in instance records are historical data, not addresses a remake may dereference. FUNC_000067 reconstructs pointers and allocates locals when loading.

## Calendar and coordinate conversion

FUNC_001357 converts the unsigned day counter using a 1,461-day cycle: the first year of each four-year block has 366 days and the next three have 365. Year zero is a leap year. There is no Gregorian century exception. The mission epoch `0x121CF7` converts to **1 January 3250**. FUNC_000021's common time path computes `ticks / 0xC22E + (days - 0x121CF7) * 86400`, with unsigned integer division of ticks. The default initializer FUNC_000147 sets ticks to `0x80000000`, so a new game begins around noon, not at the epoch's midnight. Preserve integer and 32-bit arithmetic.

| Root child script | Threshold days | Calendar date at threshold |
| --- | --- | --- |
| 12 | 140 | 21 May 3250 |
| 13 | 448 | 25 March 3251 |
| 14 | 476 | 22 April 3251 |
| 15 | 644 | 7 October 3251 |
| 16 | 672 | 4 November 3251 |
| 17 | 756 | 27 January 3252 |
| 18 | 784 | 24 February 3252 |

These convert the root thresholds already recorded in the source supplement. They do not make every child offer available on those dates: journal publication and child conditions intervene. Preserve the root comparison operators at the boundary.

Source coordinate formatting extracts `x = (code & 0x1FFF) - 0x1718`, `y = ((code >> 13) & 0x1FFF) - 0x1524`; the upper six bits select a system within the sector. Evidence: FUNC_000076's coordinate-formatting path and FUNC_000830. Do not discard the upper bits when comparing destinations.

| Packed system | Sector x,y | Upper selector | Used by inspected scripts |
| --- | --- | --- | --- |
| 447026967 | -1,4 | 6 | F01 race advert |
| 44373784 | 0,4 | 0 | Alioth return and Argent offers |
| 44381975 | -1,5 | 0 | F02 medicine market |
| 44308249 | 1,-4 | 0 | F03 pickup |
| 111433496 | 0,-2 | 1 | F03 destination and F05 target system |
| 715396891 | 3,-4 | 10 | F06 intermediate destination |
| 178534171 | 3,-3 | 2 | F06 final destination |
| 312768276 | -4,-1 | 4 | F04 target system |

`expr56(objectIndex)` reads the physical object's signed 32-bit **random seed at +0xA0**. It does not calculate a hash of the displayed station name. `srctools/plstate.txt` identifies the field; the expression interpreter reads it directly. Keep seed equality as the destination predicate. In ARGENT's active scene, seed -1008205344 belongs to Ghandi and seed 1327503611 belongs to New Rossyth, both in Alioth. This directly binds the F01 finish and F14 return predicates to named objects in this saved scene. Other station seeds still need their generated scenes or matching fixtures; guessing a seed from a familiar name is unsafe.

## Journal publication is part of the mission state machine

Script 1 creates Imperial Herald, Federal Times, RIG, Frontier News and Universal Scientist in slots 0-4, assigned to globals 17-21 respectively. All five have a 28-day issue interval and a 600-day retention setting. Their type selectors are 1,2,3,5,4, distinct from slot numbers. Script 19 controls availability/subscription offers by allegiance and additional state; do not assume all journals are accessible everywhere.

Command 14 queues `(journal slot, article ID, priority)` through FUNC_000098 with flags and earliest day zero. Its final argument, often 20 or 30, is **priority, not a delay in days**. Command 15 removes an article; command 16 replaces a matching ID. Expression 32 calls FUNC_000085 and searches the published list. It tests publication, independently of whether the player opened or read the article.

FUNC_000090 considers issue processing on its event-15 path when a journal is enabled, an update is due and its blocking flag is absent. FUNC_000089 sets the next issue day to current day plus the issue interval, removes sufficiently old published entries, then chooses an eligible pending article with the greatest priority. At equal priorities the linked-list traversal can replace the current candidate. Publication moves the article to the published list, stamps its actual day and dispatches event 7 carrying the journal and article identifiers. This event/queue cadence means elapsed calendar time alone is insufficient to reproduce offers.

For example, controller 6 first queues article IDs 247/248/249/250 to globals 20/18/17/19 and waits for any to occur in the corresponding published list. It then queues 251/252/253/255 to globals 20/18/17/21 and waits again before starting the medicine market for another 56 days. The ARTWORK save already contains script 74 with deadline 4,881,600 seconds: **26 February 3250 at 12:00:00**. This is a concrete instance, not a universal fixed opening date.

## Verified start saves and contract parameters

The dates below are source-algorithm conversions of stored values. Calendar time and current world position can differ from the scenario readme's narrative summary. A start save is not evidence of a successful ending.

| Archive member | Saved day | Active mission evidence | Specific stored parameters |
| --- | --- | --- | --- |
| ARGENT | 29 September 3252 | Controller 78 phase 12; offer controller 80 phase 1 | Alioth system 44373784, docked flight state 48; global 62 = 87,091,259, converting to 5 October 3252 00:00:59. Cash 49,954,212 tenths. This is the offer checkpoint before the expedition, not a completed first expedition. |
| HIKERS | 20 February 3251 | Script 42 phase 1 and roster helper 43 | Global 37 = 38,710,387; two-hiker contract accepted. Initial timing anchor is 25 March 3251 00:53:07. |
| ARTWORK | 5 January 3250 | Script 66 phase 1 and roster helper 67 | Global 51 = 6,609,600; script 66 local 4 roster handle 1. The current generated scene is Barnards Star, despite the readme describing a Ross 154 start. |
| DENTRA | 17 August 3250 | Script 32 phase 1 and helper 33 | Local 2 selector 55; local 3 target seed -20595497; local 4 scheduled time 29,107,991 = 3 December 3250 21:33:11; local 7 issuing system 178558746. |
| SCINTIST | 7 February 3251 | Script 25 phase 1 and helper 26 | Local 2 selector 55; local 3 target seed -408661711; local 4 scheduled time 36,714,784 = 1 March 3251 22:33:04; local 7 issuing system 111417112. |
| DENTRA_2 | 24 March 3251 | Script 35 phase 1 and helper 36 | Target selector 43, seed 687796064; departure 41,201,034 = 22 April 3251 20:43:54; target system 245659414; station-selection seed -2007870239; reward 50,000 credits. |

Selectors remain raw until the ship-generation path establishes their meanings. They must not be mapped to a mesh by equating a scenario's player ship with its target ship. Unassigned local slots can contain arbitrary historical heap data; retain defined assignments and control flow rather than treating every saved integer as a valid mission field.

## F03 pickup and delivery graph

Script 66 acceptance creates a roster entry, starts helper 67 and enters phase 1. Pickup requires system 44308249, station seed -606626917 and flight state 48. The phase-1 wrong/missed-pickup guard is `builtin[6] > global[51] - 1814400 + 1200`. At the pickup port, phase 2 waits for `builtin[6] > global[51] - 1814400`, displays the loading message, attempts three command-43 AI-ship spawns and enters phase 4. Leaving flight state 48 before loading returns to phase 1. `builtin[6]` uses the common source time path, not an independent real-world timer.

In ARTWORK, those boundaries convert to **25 February 3250 12:00:00**, and twenty minutes later for the missed-pickup branch. Global 51 itself converts to 18 March at noon. These stored values disagree with the walkthrough's 14 March pickup and 4 April deadline; do not silently substitute one profile's schedule into the other. A different initialization/revision or edited scenario remains possible.

Phase 4 starts the loaded roster helper. Arrival at system 111433496, station seed -2074987428, state 48 sets success local 9 and enters phase 3. The missed-pickup path instead enters phase 3 with local 9 zero. Phase 3 performs its outcome only at that same destination: success pays 6,000 credits, adds 5 reputation and sets global 49 to -1; failure pays zero, subtracts 1 reputation and sets global 50 to 1. It removes helper/roster/controller once. **No delivery-date comparison appears in phases 4 or 3.** A remake's additional late-delivery failure would change this source graph. Command 43's spawn wrapper is now traced below; the resulting hull/loadout, physical placement and original-game outcomes still need fixtures before full encounter parity.

Required checks: pickup exactly at the strict boundary and one second later; leaving while waiting; twenty-minute miss boundary; correct system/wrong seed; missed pickup followed by destination arrival; delayed loaded delivery; helper cleanup; save/reload with arbitrary unused local values.

## F06 displayed schedule and effective cutoffs

Use `t = global[37]`. Script 41 displays t, t+56 days and t+84 days. HIKERS therefore advertises **25 March, 20 May and 17 June 3251**, all at 00:53:07 under the source converter. Script 42's actual phase-7 late-arrival test uses **t+140 days**, which is **12 August 3251 00:53:07**, not the displayed June date. This is a source discrepancy, not evidence that every retail executable behaves identically.

Acceptance requires at least two free berths. Phase 1 maintains warnings after t-2 days, t+2 hours, t+1 day, t+26 hours and t+28 hours. The last enters phase 2, sets a further ten-second timer, then repeatedly invokes command 21 on the player after expiry. A docked/landed state 42 or 48 after t at the wrong intermediate destination goes to failure: zero credits, reputation -1 and roster removal. The correct intermediate predicate is system 715396891 and seed 1435025298. A qualifying state-42 landing can advance before t because the second arrival guard has no date test.

Phase 3 starts helper 43 for the interim roster text. State 42 at the intermediate destination enters phase 5; leaving state 42 returns to phase 3. At t+56 days, phase 5 advances to phase 6. If still waiting beyond t+132 days, another guard fails the contract. Preserve guard order: the t+56-day transition is tested before this later timeout, so that timeout is not automatically reachable during normal uninterrupted execution.

Phase 6 warns immediately, again after twenty seconds, then invokes command 21 after forty seconds. Leaving state 42 attempts four command-43 AI-ship spawns and enters phase 7. Hull/loadout, physical placement and attack outcomes remain to be verified; the source's warning and timer values are established.

Phase 7 repeats the warning progression around **t+140 days**, ending in phase 2 after t+141 days+4 hours. Docked/landed arrival after t+140 days fails before the success guard. Successful delivery requires system 178534171, station seed -2071738466 and flight state 48; it pays 6,000, adds 5 reputation and removes the roster/helpers. There is no minimum final arrival-date check in that success guard. Command text names Finn in Edethex; the walkthrough's Singh attribution remains a separate disagreement until the generated scene binds the seed to a name.

Required checks: one/two berths; reputation rejection; early intermediate landing; state 42 versus 48; every warning/timer boundary; leaving before/after pickup; final arrival on the displayed June date, one second after it, exactly at the August cutoff and one second after it; NPC/payload side effects; reload during both destructive timers. Keep displayed text, effective logic and any deliberate bug repair as separate fields.

## Verified destructive and ship-spawn commands

Command 21 resolves its target object, converts negative damage to 0x7FFFFFFF in FUNC_000953, broadcasts damage callbacks and applies shield/hull damage. The destructive F06 timers therefore attempt lethal player damage; event interception and death handling still need the selected runtime. This is not a normal contract-abandonment message.

Command 43 follows JUMP_000414 through FUNC_000668/669/772/773. Its first operand is the target object index, its second is copied into object field +0x11A, and its final expression is a **result destination**, assigned the created object index or zero on failure. The wrapper selects generator type 2, sets AI state 9, target byte +0xFE, placement parameter 0x00315000 through FUNC_000702, random target offsets and event 23. Exact physical units, model/loadout distribution, AI combat and the overloaded +0x11A field need further tracing; do not treat the second argument as a proven ship-name seed.

F03 makes three independent attempts with new expr50(-1) values, overwriting local 6 each time. Phase 4 subsequently overwrites local 6 with its new roster-helper handle. F06 generates local 9 once and uses it for four attempts, overwriting local 8 with each result; local 8 previously held an interim helper handle. These calls create encounters rather than load a commodity. Preserve allocation failures, RNG call order and these result overwrites. The source itself can advance even if a ship could not be allocated.

## F10 Junior's Friend delivery condition

Controller 14 waits for RIG article 324, sets `t = global[42] = currentTime + 56 days + remainder(RNG,172800)` and global 43 to 1, then starts helpers 53/54. The random extension is 0-172,799 seconds, not an integer number of days. After a further 29 days it queues article 333; publication removes advert helper 54 and terminates the controller. This is a journal-dependent offer lifetime, distinct from the accepted contract's pickup deadline.

Script 55 opens the response and rejects when `reputation < -remainder(RNG,9)`. Acceptance action 43264 checks at least one free berth, removes the advert parent, creates a type-7 roster record, starts helper 56 and enters phase 1. The accepted script does not increment used berths at acceptance or pickup. A roster record alone is not a cabin reservation. Global 43 is used as a helper/response reference count; preserve its initialization, response increment and close/completion decrements.

Pickup requires system 446977818, station seed 1104215363 and flight state 48. If `time > t`, the missed-pickup branch removes the roster/helper, decrements global 43, applies reputation -2 and terminates with no payment. Otherwise it displays the boarding message, starts helper 56's loaded-text variant, records pickup time `p = builtin[5]` and enters phase 2. Dialogue identifies the pickup as New California/Liaququ and the destination as Edmunds/Tracy/Fawaol; scene-to-seed mapping still needs fixtures. No commodity or measured dolphin-health field is read by the delivery branch.

Phase 2 delivery requires system 514078490, seed -742317901 and state 48. It evaluates `remainder(RNG, time-p) < 432000`. True pays 2,000 credits and reputation +5; false pays 1,000 and reputation -1, using the injured-dolphin message. Thus positive elapsed transit of at most five days always satisfies the full-payment comparison; later arrival uses this exact random test, rather than a fixed five-day failure. Preserve the source RNG call order and unsigned remainder. A zero elapsed interval has no divide-by-zero guard in expr50; record it as an edge case, not a normal attainable journey between these systems. There is no separate phase-2 absolute deadline.

Both delivery branches remove the original roster/helper, decrement global 43 and terminate. The auxiliary loaded-text helper terminates itself on initialization. Confirm its effect on definition-shared text state against the selected engine rather than assuming a separate permanent passenger object.

Primary references: ffebmp.asm controller 14 DATA_000167-176; helpers 53/54 DATA_000161-166 and DATA_000137-143; contract 55 DATA_000146-160; helper 56 DATA_000131-134; ffedat.asm DATA_002126-140; ffe.asm JUMP_000286/FUNC_001476 and FUNC_000314. All functions retain source lines and byte offsets in the structural graph.

Required checks: zero/one free berth; response rejection and repeated openings; pickup equality and one second after; one second before/exactly/after five elapsed days with fixed RNG; repeated late deliveries; no added cabin reservation; wrong station seed; helper/global-43 cleanup; full roster; reload during transit. Source core is R1; original scenes, shared-helper UI and successful/failed runtime fixtures remain R2.

## F11 Five Furies effective pickup and reward rules

Controller 17 waits for publication of article 342/340/341 in Frontier News/Federal Times/Imperial Herald, then sets `t = global[45] = currentTime + 112 days + remainder(RNG,40) * 1 day`. Thus the generated offset is 112-151 whole days, preserving the current time of day. Helper 57 displays pickup at **t-3 days** and delivery at **t**. The advert is offered on event 1 when expr49 identifies the system as allegiance 2 or 3; its controller stops offering when `currentTime > t-4 days`. This is publication-relative scheduling, not a universal March pickup date.

Script 58 accepts action 43380, removes its advert parent, creates a type-7 roster item and starts helper 59. This script contains no spare-cabin check or cabin-count mutation; command 37's FUNC_000314 creates the roster record without reserving a cabin. The historical walkthrough's cabin requirement remains a separate observation to test against a selected executable, rather than an invented source predicate.

Phase 1 pickup requires system 178542358, station seed -1407957691 and flight state 48. Its ordered branches are:

| Arrival time | Outcome |
| --- | --- |
| `time > t-2 days` | Missed pickup; pay zero, reputation -1, remove roster/helper and terminate through phase 2. |
| `t-4 days < time <= t-2 days` | Display hurry message, start loaded-text helper, advance to phase 3. |
| `time <= t-4 days` | Display normal loading message, start loaded-text helper, advance to phase 3. There is no earliest-pickup wait. |

Phase 3 requires delivery at system 111449881, seed -470378999 and **flight state 42**. It pays 2,000 credits even after t+1 day. Reputation increases by 5 only if `time <= t+1 day`; otherwise the increment is zero. Completion removes the original helper/roster, decrements global 44 and terminates. No cargo selector, statue condition check, lethal timer or independent delivery-failure guard appears in this graph. Fort O'Brien/Oliverport names are supported by the script's dialogue; matching generated scene seeds still need runtime fixtures.

Primary references: ffebmp.asm controller 17 DATA_000798-811, helper 57 DATA_000775-781, contract 58 DATA_000782-797, helper 59 DATA_000771-774; ffedat.asm DATA_002141-155; ffe.asm FUNC_000314. The structural graph retains source lines and instruction offsets for each function.

Required checks: advert equality at t-4 days; early pickup; both pickup boundary equalities and one second after; state 42 versus 48 at delivery; payment/reputation at t+1 day and one second later; no cabin; full six-entry roster; shared helper state across multiple responses; reload after pickup. This is an R1 source core with original-game parity still unverified.

## F12 Jan Thikka boarding, negotiation and promotion defects

Controller 18 waits for Imperial Herald article 344, then sets `t = global[48] = currentTime + 112 days + remainder(RNG,40) * 1 day`, generates global 46 with expr50(2147483647), clears global 47 and starts helpers 60/61. Script 61 offers the contract on event 1 only in a system whose expr49 allegiance is 2. Offering stops at **time >= t-2 days**, sets global 47 and terminates that advert. Accepted script 62 has its own subsequent checks.

Script 62 initializes remaining payment local 2 to 2,000, proposed advance local 7 to zero and negotiation-used local 8 to zero. A first half-payment request sets local 8, uses expr50(2), and either refuses or sets local 7 to 1,000 and reduces local 2 to 1,000. Asking for all cash refuses and also consumes this negotiation opportunity. **Acceptance never adds local 7 to the cash balance.** In this source graph a promised advance reduces the eventual reward without an explicit advance transfer. Default successful payment is 2,000; the promised-half branch explicitly pays only the remaining 1,000 at hand-in. Preserve this source defect separately from an adapted payment fix and verify the original executable before claiming its runtime outcome.

Acceptance creates a roster entry and helper 63, without reserving a berth. Phase 1 waits for system 446969616, seed 1561099119 and flight state 48, then enters phase 2. An ordered later guard sets failure local 9 to zero and enters phase 3 only when `time > t+1 day`. Because the matching-port guard runs first, remaining at that port after the window can enter phase 2 before the failure guard.

Phase 2 returns to phase 1 if state !=48. Otherwise silent boarding requires **t <= time <= t+1 day** and at least one free berth: builtin15-builtin16 >=1. Boarding increments used berths, sets local 9 to 1 and enters phase 3. There is no explicit phase-2 timeout; waiting past the window in state 48 with no free berth can stall until departure causes phase 1 to run again. Do not infer passenger loading from arrival alone. This accepted graph does not start the loaded variant of helper 63 after boarding, despite that variant existing in the helper definition.

Phase 3 resolves at **any allegiance-2 system** when flight state is 42 or 48. Success decrements used berths if positive, sets global 46 to -1 and computes the Federal-points increment below. Failure sets payment zero, proposed points increment -1 and global 47 to 1. Both paths apply their payment, invoke command 53 `(2, increment, -1)`, remove helper/roster and terminate. A named Wafaphi base is therefore a walkthrough example, not the source's sole hand-in location. The return graph has no further time limit after successful boarding.

### Federal promotion is not an unconditional rank increase

Expression 34 with selector 2 reads Federal military points DATA_008912. On success script 62 starts r=1, increments r while `r^4 <= points` and r<13, then proposes `delta = r^4 - points`. The first twelve thresholds in ffedat.asm DATA_005114 are 1,16,81,256,625,1296,2401,4096,6561,10000,14641,20736, followed by 65535. The script's r=13 cap and the final engine threshold are distinct.

Command 53/JUMP_000434 passes the proposed delta's **low byte** to FUNC_000304. FUNC_000306 treats that byte as signed, applies the resulting increment/decrement and clamps an excessive decrement at zero. Thus a large proposed promotion can wrap into a smaller increment or a decrement. Examples derived directly from these operations:

| Starting Federal points | Proposed delta | Signed byte applied | Resulting points |
| --- | --- | --- | --- |
| 0 | 1 | 1 | 1 |
| 16 | 65 | 65 | 81 |
| 81 | 175 | -81 | 0 |
| 128 | 128 | -128 | 0 |
| 255 | 1 | 1 | 256 |
| 256 | 369 | 113 | 369 |
| 625 | 671 | -97 | 528 |

These are calculated source outcomes, not observed saves. For failure, the explicit -1 delta reduces points by one with zero-floor handling. Record exact points before/after; a generic 'one Federal promotion' implementation would not reproduce this pinned source's arithmetic.

Primary references: ffebmp.asm controller 18 DATA_000740-749; helpers 60/61 DATA_000706-711 and DATA_000734-739; contract 62 DATA_000712-733; helper 63 DATA_000702-705. Supporting routines are ffe.asm JUMP_000264-266, JUMP_000285/FUNC_000871, JUMP_000434-435, FUNC_000304/306 and FUNC_000314; field evidence is srctools/gmstruct.txt. Dialogue mapping uses DATA_001699's 512-entry selector mask via FUNC_000062; story strings DATA_002178-198 identify Jan and the mission without substituting global-variable names.

Required checks: negotiation refusal/acceptance and repeated requests; cash immediately before/after acceptance and hand-in; t and t+1 day equalities; arrival after the window while still docked; occupied cabin until after the window; takeoff/re-dock; any Federal surface/orbital hand-in versus another allegiance; points 0/16/81/128/255/256/625; promotion/demotion notices; saved shared-helper state and roster capacity failure. Core predicates and arithmetic are source-backed; calendar instances, generated station scenes and original-game outcome fixtures remain R2.

## Remaining boundary

FFE remains R2 as a whole. Journal data, epoch conversion and six static start checkpoints are now recovered. F01's uninitialized deadline still lacks an active race fixture. Full action semantics, target generation/AI, all named station mappings, Argent ship/cash/cargo restoration, vaccine branches, unfinished-branch reachability and successful/failed/reloaded original-game runs remain open. The saved graphs and checkpoints make these specific checks reproducible; they do not justify marking every mission complete.
