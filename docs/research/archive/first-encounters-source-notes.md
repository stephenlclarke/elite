# First Encounters mission-script evidence

**Archived and excluded from implementation by owner instruction on13 October2026. See [active scope](../implementation-scope.md). Ship data may remain available separately.**

Source S39 is John Jordan's reverse engineered and modified JJFFE 2.8 source, pinned to `7e540341d4e09aa3c92877b87d49e7f2c143ad8d`. It is an additional version profile; it is not proof of unchanged behaviour in the original DOS release or every later patch. The source's own installation notes require the separate `mission.dat` journal file. S43 now supplies a file fitting all 671 slots in the source offset table; [journal and save profiles](ffe-journal-and-save-profiles.md) establishes its hashes, six start checkpoints, calendar conversion and journal operations. Mission text, journal article numbers and script indices are different namespaces.

## Recovered structure

[data/ffe-script-graph.json](data/ffe-script-graph.json) records all 105 entries of `ffebmp.asm`'s `DATA_001697`, with phase order, initial actions, guard conditions, byte offsets, argument bindings and source line numbers. It contains 1,019 unique function records. Structural validation found no decoding errors and no nonzero trailing bytes in any function. This establishes a complete structural parse of the embedded script table, not complete semantic verification or 105 independent missions. Many entries are journal, dialogue, encounter and contract helpers.

Each fact must be checked against `ffe.asm` before translating a raw command into game behaviour. Unresolved expressions retain `exprNN`; unresolved actions retain `commandNN`. The dataset contains no original dialogue or journal prose. Do not feed it directly into a game engine as if all opcodes had verified meanings. In particular, `ffedat.asm`'s dialogue name table emits local-variable expressions; applying those names to global slots creates plausible but incorrect variable names.

Relevant interpreter routines: FUNC_000020 reads a signed little-endian 32-bit operand; FUNC_000021 reads built-ins; FUNC_000031 evaluates prefix expressions; FUNC_000037 assigns an expression target; FUNC_000041 runs commands; FUNC_000051 allocates an instance; FUNC_000052 binds arguments; FUNC_000053 evaluates a phase; FUNC_000054 schedules active instances; FUNC_000055 starts the root. Script-definition offsets 0 and 4 refer to argument/static data, not phases. Phase pointers begin at offset 0x1C.

The instance's local slot 0 is its own handle, slot 1 its parent handle. `FUNC_000051` allocates the remaining local array with `malloc` and does not clear it. Only the two handle slots are explicitly initialized there; argument binding and phase actions must establish other values before use. Do not assume zero-filled locals. Phase initial actions run before its ordered guards. A phase-changing command ends that pass; do not evaluate guards from the new phase against stale local state. Guards and jumps use the source's signed integer and prefix-expression semantics. Expression opcode 4 accesses global DATA_008548 storage; opcode 5 accesses definition-shared storage; opcode 6 accesses per-instance locals. Preserve these lifetimes separately.

Built-in selectors 5 through 11 all take the same time path in this source: integer ticks divided by 0xC22E, plus `(dayCounter - 0x121CF7) * 86400`. Keep this source timer domain. A walkthrough's calendar date is insufficient to reconstruct its exact integer boundary or infer separate wall clocks from the different selector numbers.

## Root dispatch and journal dependency

Root script 0 starts scripts 1-11 immediately. Its later guard thresholds start scripts 12-18 at these source-relative seconds:

| Script | Threshold seconds | Days from source epoch |
| --- | --- | --- |
| 12 | 12,096,000 | 140 |
| 13 | 38,707,200 | 448 |
| 14 | 41,126,400 | 476 |
| 15 | 55,641,600 | 644 |
| 16 | 58,060,800 | 672 |
| 17 | 65,318,400 | 756 |
| 18 | 67,737,600 | 784 |

The root advances a progress flag for each dispatch, then terminates after the last. These are scheduler thresholds, not automatically the advert's opening dates: child scripts often wait for journal events before creating contracts. Script 16 starts the large Argent campaign controller 78 and journal helper 79. The source calendar now maps the epoch to 1 January 3250; threshold dates and a matching journal offset table are documented in the [journal and save profiles](ffe-journal-and-save-profiles.md). Journal scheduling still intervenes before offers; preserve profile-specific dates.

## Verified F14 flora advert and agent branches

Script 82 (`DATA_000678`) owns the flora advert. Initialization stores `time + 2,419,200` (28 days). Its advert guard requires global event 1, packed system 111507224 and current-station object seed -2104442410. Advert action code 43092 starts script 84. The expiry guard is strictly `time > storedDeadline`, not >=. The text identifies the delivery pretext as Old English roses; do not interpret the pretended rose delivery as a separate campaign from rescuing the agent.

Script 84 (`DATA_000698`) initializes a 30-second response deadline and presents the agent dialogue. Choice action 43098 records an agent handle, sets global slot 64 to 1 and changes phase. Closing the dialogue (global event 2), or strictly exceeding 30 seconds, takes a different phase. That phase presents the arrest response and stores a further ten-second deadline. Its expiry invokes command 21 on the player with arguments -1 and 0. `JUMP_000386` calls damage routine `FUNC_000953`, which converts negative damage to 0x7FFFFFFF, broadcasts damage events and then applies shield/hull damage. This is a lethal-damage attempt, subject to event handlers; verify the selected build's player-death path and interception before claiming guaranteed termination.

The accepted branch waits for Alioth, packed system 44373784, while flight-state code !=4, then enters its return phase. That phase switches back if the player leaves Alioth. Completion requires Alioth, current-station object seed 1327503611 and flight-state code 48; command 38 removes the agent handle, then the script terminates. This corroborates the destination-bound passenger objective and provides exact predicates rather than a generic "dock anywhere in Alioth" implementation. These are object seeds, not string hashes. The ARGENT start save directly binds Alioth seed 1327503611 to New Rossyth. Other names still require the matching generated scene; do not substitute arbitrary modern station IDs.

## Additional corrections and source leads

F06: script 42 checks at least two free passenger places. Its first-leg system/station predicates are 715396891/1435025298 and its second-leg predicates 178534171/-2071738466. The final leg requires flight-state 48; success sets cash parameter 6,000, reputation increment 5, then adds ten times the cash parameter to the internal balance. The source text identifies Solo's Rock and Finn in Edethex; the earlier walkthrough's Moore Starport/Singh wording is a documented disagreement. The HIKERS checkpoint now binds the displayed March/May/June schedule and the source's later August failure cutoff. The [detailed graph](ffe-journal-and-save-profiles.md) preserves this discrepancy; station-name binding and outcome fixtures remain open.

F03: script 66 fixes the successful delivery cash parameter at 6,000 and reputation increment 5. At pickup, the successful on-time predicate uses `time > (global[51] - 1,814,400)`; missing the pickup enters another branch after a further 1,200 seconds. Script 67 supplies the contract description. The destination predicate is packed system 111433496, station object seed -2074987428 and flight-state 48. The ARTWORK save now binds the pickup to 25 February 3250 at noon, contradicting the walkthrough schedule; the inspected loaded-delivery phases have no date check. See the [complete pickup/outcome graph](ffe-journal-and-save-profiles.md) before adding a late-delivery rule.

F01/F02 are expanded below. The random-number expression and UI payment propagation have now been traced to their interpreter implementations; source quirks still prevent assuming a deterministic race deadline or one fixed medicine price across builds.

The Argent briefing text corroborates Pleione (32,32), Polaris (0,76), and Hotice (-3,-2). The New Rossyth instructions distinguish the red response from green's immediate return-to-Alioth instruction. These are dialogue-supported itinerary facts; the corresponding trigger and ship-boarding code remains necessary. S17's unfinished-branch reports are still separate from a reachability proof: surviving text alone neither proves a playable branch nor proves every related script is unreachable.

## Verified random-number expression

Expression 50 maps to `JUMP_000286`, which calls `FUNC_001476`, evaluates its single argument, then returns the unsigned remainder of the generated 32-bit value divided by that argument. The RNG call occurs before argument evaluation. Its two 32-bit state words are DATA_008818=A and DATA_008820=B: save oldA; set A=(A+B) modulo 2^32; set B to oldA rotated sixteen bits; return B. No zero-denominator guard exists. This establishes the arithmetic and call order; the selected start save must supply both seeds. Modulo reduction is not automatically an exactly uniform distribution for every divisor. Expression 53 instead calls a ship-generation wrapper and must not be called a second random-integer operation.

The structural JSON keeps `expr50` to preserve the original opcode number and now includes a `verified_semantics` section. Consumers must opt into those meanings explicitly; unresolved opcodes remain unresolved.

## F01 Wiccan Ware Race: rewards and deadline defect

Controller script 6 initializes prize parameter global[56] to `1000 + remainder(RNG,1000)`, hence an integer 1,000-1,999. It starts advert script 73, whose source/station predicate is packed system 447026967 and station object seed 1863904092. The advert stops at `time >= creationTime +25 days`; its internal stored value is creationTime+27 days with two days subtracted by the expiry guard. Acceptance in script 75 removes the advert parent and invokes command 37 to create a mission roster item with type 7, storing its returned handle in local[2]. Closing before acceptance terminates the response without accepting.

Race completion requires packed system 44373784, station object seed -1008205344 and flight-state 48. On that event, compute `r = old local[3] - time - remainder(RNG,259200)`, storing r back into local[3]. Branches are r<0: winner message, update the global winner records, add `prize*10` internal tenths of a credit and increment reputation by one; otherwise r<500: runner-up message and add integer `prize/10` internal tenths; otherwise: late message, no payment. Remove the roster item and terminate in all three paths. Thus the winning parameter is 1,000-1,999 credits; the smaller payment is only 10.0-19.9 credits after integer truncation. The historical 1,010-credit example is one possible prize, not the fixed source reward.

**Unresolved source defect:** script 75 declares four local slots but its decoded initialization/acceptance actions never assign local[3] before that arrival calculation. The allocator uses uninitialized `malloc` storage. Command 37 writes only the roster handle to local[2], not a deadline to local[3]. This is evidence of a potentially undefined initial deadline in the pinned JJFFE source, not proof that every retail build always wins, always loses or has a three-day limit. Recover an original executable/save fixture and inspect the local value and heap initialization before promising deterministic parity. A corrected deadline is a deliberate adaptation and needs its own profile.

## F02 Soholia medicine relief: availability and actual sale prices

Controller 6 starts script 74 after its journal-condition group succeeds, passing packed system 44381975 and expiry `time +4,838,400` (56 days). The two article groups and calendar algorithm are now bound in the [journal profile](ffe-journal-and-save-profiles.md). ARTWORK stores this instance's expiry as 26 February 3250 at noon; it is not a universal fixed date. Script 74 starts its local market-price override only while the player is in that system and terminates the child on departure. The override is script 76, commodity selector 1008 and raw market-price parameter 12,000; the world market's unit/rounding must be checked before translating that raw parameter into a displayed price. The mission advert and override expire only when `time > deadline`, including a separate expiry guard while in the system.

Script 77's initial sale UI entry is action 43473, current medicine count, label code 36360 and raw amount 20,000. Command 56 appends these fields as a service entry. `FUNC_000360` copies the selected entry's fourth field into global[3] before firing its action event. On action 43473, a zero medicine count invokes the no-goods message; otherwise add global[3] to cash, subtract one medicine unit, increment reputation by one and redraw the sale option. Expression 37 with selector 1008 reads the player's medicine cargo count; assignment uses the corresponding cargo mutation branch.

The redrawn option uses raw amount **36,000**, not 20,000. With cash stored in tenths, the first sale through a newly opened dialogue pays 2,000 credits and repeated sales through that dialogue pay 3,600 each. Closing terminates script 77; reopening the advert creates a fresh response script with the initial 2,000-credit option. This source-specific distinction supersedes a universal 2,000-per-tonne claim. The market override and mission buyer are separate price paths. Verify first/repeated/reopened sales, zero cargo, exact deadline, leaving and re-entering, reputation increments and save/reload against the selected binary before calling the whole mission R1.

## Remaining fidelity work

R2 overall. Resolve every raw opcode through its called functions, finish journal issue/outcome fixtures, map remaining station seeds to generated names, identify ship/equipment selectors, and replay each reachable outcome. Test refusal, closing a response window, exact deadline equality, partial cash payments, NPC outcomes, escape/hyperspace, retained passengers and old-ship restoration. Save and reload across active phases, including shared variables. The structural graph makes these checks traceable, but zero parse errors are not runtime proof.
