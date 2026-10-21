# Shrews' Rights

O07 P34, Zafrusteria's 0.8, is one Galaxy 2 campaign supporting an emerging sapient Shrew population. The [structured graph](data/shrews-mission-graph.json) contains all 23 source stage records,29 news records and43 dialogue-choice callback results from Scripts/ShrewsRights.js and Config/missiontext.plist. Package/AI/ship-script hashes remain in [provenance](data/oolite-pack-sources.json). These source records establish the campaign inventory and selected control flow; labelled repairs below define a coherent project adaptation without claiming an original-engine playthrough.

## Route and station handoffs

Require galaxyNumber 1 and score >=512. Initial news is after total jump counts 2,3,5, with the second directing the player to Arries. All numbered system IDs below are zero-based in Galaxy 2. Main-station docking delivers conversations/handovers; the owner-authorized project adaptation presents them as docked services rather than walking scenes.

| Stage | Place or trigger | Result |
| --- | --- | --- |
| 1 | Arries238 | Meet campaign contacts; accept route to Ramaan. One nested acceptance pays 1,000 credits. |
| 2 | Ramaan161 | Receive encrypted data crystal; head to Envebe. |
| 3 | Envebe177 | Continue to Zatebiso. |
| 4 | Zatebiso204 | Continue to Xeatxe. |
| 5 | Xeatxe150 | Transfer crystal, receive dispersal device; continue Vesozaxe. |
| 6 | Vesozaxe143 | Continue Arries. |
| 7 | Arries238 | Receive White-spot as a quest passenger; continue Diti. |
| 8 | Diti33 | Hand over White-spot; continue Veriar. |
| 9 | Veriar5 | Recover Liberate Sorex black box in space, or receive it through the station contact alternative. |
| 10/11 | Black-box recovery/data screens | Read evidence; direct player to strike a Veriar buoy. |
| 12 | Attack a CLASS_BUOY at Veriar5 | Record attacked object's name and advance13. Destruction can change the report to destroyed in the repaired profile. |
| 13 | Enter Vezaaes82 station aegis | Stand-down message; continue14. |
| 14 | Vezaaes82 main station | Transfer the device; proceed to Diti. |
| 15 | Diti33 | Original trial/hearing becomes station handoff P34-STATION-TRIAL; transfer black box, resolve hearing, clear applicable offences and pay 3,000 at the final recorded choice. |
| 16/17 | Final assignment news and contact | Locate Tiaras Skeets in a generated nearby system; accept hunt or finish/temporarily defer. |
| 18 | Enter the chosen second search system | Spawn Whiskers/Tiaras at witchpoint, advance19 and track alive/captured/killed/lost outcomes. |
| 19/20/21 | Main-station debrief | Still circling/alive, lost in space, or captured/killed outcome respectively. |
| 22 | Terminal | Campaign completed or abandoned, according to the recorded ending. |

The source crystal/device/passenger/black-box items are portable, undamageable, TL99 zero-price equipment wrappers. Keep their canonical quest identities and custody separate from ordinary commodities. Project White-spot transport requires an available passenger berth, explicitly adapting the source equipment-only passenger; check fit before accepting that handoff. If none fits, leave it pending. The device's original deployment and trial narrative have no playable ground counterpart: station representatives receive the device/evidence and deliver the corresponding established exit state. Record mapping 15 entry to its final n16 exit, charge no added fee/time and preserve the source 3,000-credit payment once. The original ground/walking narrative remains reference-only.

## Dialogue graph and news

The JSON choice_paths list is authoritative for exact keys/redirects/payments. Message key is ShrewsRights_msg +stage+substage, initially substage m. Choices are numbered 1..9 until the first absent key; with none, choice 0 closes the message. Cash comes from the choice's c suffix when it is a signed integer string. Only two positive payouts exist in this table:1,000 and3,000. The apparent fuel compensation formula is guarded by stage.fuel, but the supplied fuel flag is on a news record instead; the stage-15 cash therefore does not automatically include an extra fuel allowance.

Redirect nN changes the stage and updates instructions without another choice screen; dN opens a stage/substage screen, including nested suffixes such as d15m1m1; jN defers with resume probability N/10. Each subsequent jump adds 0.03, resumes when probability >random or >1, advances one stage and announces after ten seconds. Preserve the exact redirect string and choice history; do not flatten all nested trial/conversation choices into next-stage increments. Back must be an explicit no-change project action rather than interpreting null as choice zero and granting rewards.

News progresses sequentially, using either stage jump count or total-jump threshold, with the full source table in JSON. Records also change descriptions/markers, enable extremist encounters or select the later pursuit system. Optional GNN affects presentation, not whether the route can progress; provide an in-game station/news log fallback. Descriptions for Envebe/Zatebiso contain inconsistent ID/label pairs in the original table; use the numerical bindings as source facts and label any corrected narrative names separately.

Original arrival handling applies some mission redirects/find-target effects before the news threshold has passed. Project repair: only consume a news record and apply its stage/route effects once its stage and threshold predicates pass; handle missed records deterministically in order. Reset the per-stage jump counter on actual stage entry rather than on reopening a screen. This defines intentional pacing instead of silently asserting the source always waits its advertised ten jumps.

## Space encounters and pursuit

While the active news record enables anti-Shrew attacks and the commander is not deferred, compute shipCount=min(floor(random*2+1)+floor(score/1200),5). Attack chance is 0.2+(((missionStage-3)/2)+(shipCount/2))/10; equality with the random draw spawns. With score <1,000, or a separate random >=0.65, spawn at the normal witchpoint location; otherwise around player at radius 10,000+random*2,000. Source role sr_extremist selects actual hulls from [expansion resources](data/oolite-expansion-resources.json), not a fabricated uniform wave.

Base attacker bounty is floor(random*5+1)+max(shipCount*8,25), missile load time two seconds and target the player. Equipment probability adjustment is +0.175 for player shield booster,+0.1 shield enhancer,+0.15 military Ironhide or +0.1 regular Ironhide,+0.025 missile analyser plus +0.1 AMS when analyser exists,+0.075 auto-ECM or +0.05 regular ECM. For reverse-loop index >3 with score >2,000, a draw >0.75-adjustment grants shield booster and7..11 bounty; index >2 and draw >0.55-adjustment grants shield enhancer and5..9 bounty. Beam upgrade occurs when count >3 and draw >0.7-adjustment, or count >2 and draw >0.85-adjustment; add5..9 bounty. The military-laser branch requires index >4, impossible when the capped count is five; do not claim it occurs in this source profile. Preserve draw order or record a deliberately rebalanced variant.

Extremist priority AI acquires/attacks a nearby player with two-second reconsideration, fights current combat target at five, approaches witchpoint at35, responds to distress at20 and otherwise reconsiders at30. It never flees to witchspace. The Tiaras variant surrenders late and has broader friendly roles; ordinary extremists favour pirates/bounty hunters. Their encounter durability, guns and missile capacities come from their selected dictionaries plus actual scripted upgrades.

At Veriar, spawn a trader derelict 16,000..17,999 from the player, name Liberate Sorex, zero bounty, no escorts/pilot, no active AI/lights. With fuel scoops, emit one black box and repeat scanner hints after five seconds then every fifteen. Player scoop grants its quest equipment and advances10. O08 still requires free hold space for scooping. Without scoops, the source has a docked contact alternative; its proximity callback incorrectly looks for a box that was never spawned, so do not make that callback a required step. The station handoff supplies the original alternate black-box exit without inventing a ground search.

First pursuit search picks a different system within7 LY; second search picks a different system with distance in [6,13] LY. Freeze the generated IDs and route reachability; an empty set stays pending. The source second encounter has one Whiskers ship, bounty201..215, full energy and a crew identity Tiaras Skeets from Vezaaes82. It attacks the player and otherwise patrols the witchpoint. Capture checks an escape capsule/suit with that exact crew identity. Crew-bearing destruction yields killed; derelict destruction without a captured crew yields lost. Captured custody starts an escape monitoring timer at20 seconds, every10; rediscovering Tiaras in a nearby escaped pod changes outcome to lost. Debrief distinguishes these outcomes and offers completion/continuation exactly as the choice graph records; there is no invented final cash bounty beyond engine rewards.

## Repairs, saving and acceptance

Normalize numeric stage redirects to integers and serialize structured TS outcome arrays as JSON. O08 missionVariables converts assigned objects to strings; saving an array directly and reading it back as an array is unsafe. Save black-box/entity references as stable IDs/custody, not object string representations. Declare the PastNames restoration loop variable under strict mode. Repair null-or-empty checks using logical AND/explicit checks rather than dereferencing null through the original OR expression. Guard null/environmental killers and empty crew arrays. The world shipKilledOther handler requires the current stage to have spawnTS, but system population already advanced from18 to19; bind later capsule kills to the saved Tiaras encounter/custody ID instead of that stale stage guard. This is a project repair, not a verified source capsule-kill outcome.

The buoy-destruction handler compares the previous stage's systemID0 against Veriar5, so it fails to update the destroyed label; repair the comparison to the intended event system. Attack recognition otherwise accepts any buoy at Veriar rather than a specific fixture, which must be preserved or narrowed as a labelled choice. Station-aegis dialogue temporarily sets ship speed/thrust/velocity to zero; source restoration depends on a fragile later GUI/stage check. Project repair pauses the simulation/dialogue safely and always restores the prior motion on exit/cancel; avoid a permanently immobilized commander or a collision while reading.

Make stage equipment grants/removals, screen payments, station handoffs, news effects and final reward IDs once-only. Persist timers by remaining time, news index, jump counters, defer probability, dynamic pursuit systems, encounter seed/hulls/damage, past names, Tiaras custody/outcome and free-docking grants. The optional docking-fee reward independently grants each of eight named systems with probability0.6, once at hearing completion; repeated screen visits must not reroll it. Store incompatible personal equipment; mission passenger/evidence capacity must remain enforced on hull switching.

Verify every JSON dialogue path, two payouts once, stage/substage redirects, defer thresholds, all route locations, no-scoop alternate, full/zero hold, missing berth, attack/destruction distinction, every news gate, environmental/player/NPC Tiaras outcomes, lost pod/capture/re-capture, cancellation and reload at every handoff. Forty-three source choice checks pass; native encounter outcomes and full campaign playthrough remain implementation validation work.
