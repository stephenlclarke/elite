# Galactic Almanac: renegade surveyor

O07 P12, Galactic Almanac 0.94, contains a hidden station-to-station campaign within its much larger naming/MFD framework. It is not simply a naming utility. Scripts/randomstationnames.js establishes all thirteen briefings, pagination, quest wrappers, news progression and payout; hashes are in [package provenance](data/oolite-pack-sources.json). [Twenty-nine source callback cases](data/almanac-source-fixtures.json) check twelve briefing/handovers, seven multipage exits, three news-queue responses, four expense boundaries and three naming choices. Original text remains reference material; the project presents every former walking/collection scene as an orbital station handoff.

## Activation and news dependency

Installation briefing advances news state0 to1. Seventeen news reports lead to state19. Their required jump counts, by source state, are1:1,2:4,3:6,4:5,5:2,6:1,7:1,8:2,9:3, then state10 waits for a docked email after >5 jumps and advances11;11:5,12:5,13:3,14:2,15:6,16:1,17:3,18:5. These are counter thresholds from the code, not an estimated total travel distance. An optional MFD introduction resets the same timer and may delay this progression. The news timer wraps to0 after exceeding99.

Source requires news_installed Yes and calls GNN._insertNews directly. A zero/falsy return advances state; a full/error queue does not, although the counter resets. Snoopers alone can set the flag but does not provide GNN._insertNews; no news integration can leave the mission inaccessible. Explicit project repair: use the game's persistent station news queue as the delivery adapter, with the same source state/jump thresholds and once-only report IDs. Display failures defer a report, not its whole narrative forever.

At state19, timer >2 and system ID not131, a docked invitation directs the player to Galaxy1/Zadies131. If already in Galaxy1, acknowledgement sets21 and marks Zadies; elsewhere it sets20, which advances21 on a later arrival in Galaxy1. No kill-score prerequisite or assignment expiry is specified.

## Briefing and handoff route

All following bindings use galaxyNumber0. Main station is required where specified. Named stations are descriptive source names; project binding uses stable station identity rather than user-editable display text.

| Entry state | Place | Source transition and handoff |
| --- | --- | --- |
| 21 | Zadies131 main station | Three-page briefing sets22, exits to24. Start expense jump counter0; visit Orrira. |
| 24 | Orrira149 main station | Three-page briefing25, exit27; obtain a lemon-soaked paper napkin at Leesti. |
| 27 | Leesti49, any station | Confirm grants unique EQ_ALMANAC_LEMON_SOAPED_PAPER_NAPKIN, state28; return Orrira. |
| 28 | Orrira149 main station | Three pages29, exit31; transfer napkin and visit Rarere. |
| 31 | Rarere119, Mining Facility: The Odd Job | Three pages32, exit34; obtain tracking information in return for arranging a ship-name correction at Lave. |
| 34 | Lave7 main station | Confirmation gives three pages35, exit37; station records staff correct Widow Maker registration, then direct player to Veisti. |
| 37 | Veisti104 main station | Grant empty temporal isolation unit, state38; return Lave. |
| 38 | Lave7 main station | Three pages39, exit41; locate renegade surveyor/ambassador at Ervein. |
| 41 | Ervein176 main station | Confirmation gives three pages42, exit44; agree to obtain a shrubbery. |
| 44 | Qubeen233, any station | Station handoff grants one contained shrubbery, state45; return Ervein. |
| 45 | Ervein176 main station | Transfer shrubbery as agreed and replace empty unit with occupied unit, state46; take surveyor to Zadies. Source retains the shrubbery wrapper until final cleanup. |
| 46 | Zadies131 main station | Remove occupied unit/shrubbery and offer Lave-station naming reward. Set47 after Yes/No; final exit pays expenses and ends49 if renamed or50 if default name retained. |

The Odd Job exists independently of mission stage: role random_station_names_easter_egg1, route sw fraction0.9 at Rarere, added during startup/arrival. Avoid duplicating it on reload. Its numerical rock-hermit/station profile is in [expansion resources](data/oolite-expansion-resources.json). No renegade ship combat or eldritch enemy encounter is spawned by this mission graph: the described attacks/abominations are narrative, not evidence for a new combat wave or alien species.

## Pagination, items and project adaptation

Three-page briefings allow1->2,2->1/3,3->1 or exit. Only the page3 exit advances the associated route state and applies transfer/markers. The JSON records all seven exit mappings. Source callbacks often ignore the submitted choice; project Back must leave the handoff pending instead of silently granting the next item. Reopening an interrupted briefing must not reset accepted route progress or the expense counter.

All four quest equipment wrappers have nominal TL100 and price3,500 decicredits, portable_between_ships Yes and damage_probability0. They are granted by script without charging that market price. Distinguish empty/occupied isolation unit and contained shrubbery from ordinary equipment/commodities. The source does not require a standard passenger cabin for the occupied unit. Project adaptation reserves one mission equipment-capacity unit for each carried wrapper, not a guessed passenger berth, and shows that capacity requirement before its handoff. This estimated fit cost follows the common unknown-module policy; retain unique item/custody IDs through hull changes.

Explicit station mappings replace the Leesti napkin collection, Qubeen botanical collection, Ervein ambassador pickup and Zadies treatment hand-in with docked contact transactions. The original in-station walking and any mentioned planetary events are research-only. Keep the same systems, quest requirements and source exit states. At the source's any-station collection stages, accept any dockable orbital station in that system. No surface station qualifies. The [handoff contract](station-handoff-specifications.md) governs confirm/cancel, capacity and save migration.

Source completion frequently trusts stage alone rather than checking wrappers. Project repair requires the correct held napkin/unit/shrubbery identities before consuming/transferring them. Retain the shrubbery through the final hand-in as the source does, instead of both consuming it at Ervein and requiring it again at Zadies. No combat penalty or timer is introduced by these service replacements.

## Reward, epilogue and validation

Expense counter increments per witchspace arrival only when news state>21 and<48. Final exit pays min(expenseJumps,250) credits and deletes that counter. It is paid on the final callback, not merely when the earlier briefing claims payment. Lave's default name is Avalonia Avenged; empty/cancelled text entry retains that name. A changed name ends49 and produces the renaming news after three jumps, then advances50. Later news stages50/51/52 require30/10/3 jumps; they are epilogues, not extra missions or cash rewards.

Persist news/timer/expense counters, route/pagination state, accepted station handoff IDs, quest wrappers, renamed Lave value, original station bindings and reward-paid ID. Final cleanup/payment must be atomic rather than removing equipment before a cancellable reward screen. Never apply the renaming to a different mutable display-name match. User text is plain station text; bound its length to the project's supported display width without altering mission reward logic.

Verify all route predicates, wrong galaxy/station, any-station exceptions, empty/full news queue, no GNN fallback, every page/back route, no/correct capacity, missing/stale/duplicate wrappers, double hand-in, expense0/249/250/251, naming/default/blank, epilogue jump gates and reload/hull switching at each stage. Twenty-nine selected callback checks pass; full native-world travel/UI and naming-system parity remain implementation validation work.
