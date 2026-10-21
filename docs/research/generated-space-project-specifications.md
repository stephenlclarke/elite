# Bounded project generators for space jobs

[Filled project profiles](data/generated-space-project-profiles.json) provide implementable parameters for fourteen retained G families. G04 uses the separately recovered [Elite-A arithmetic](elite-a-courier-specifications.md). These profiles adapt documented objective structures into this project's space/station game. **Their bounded generation, rewards, quotas, timers and encounter choices are labelled project estimates; they are not recovered Elite Dangerous live-server distributions.** Original story mission values always take precedence over this optional generic generator.

## Common contract

Difficulty is an explicit1/2/3 selection. The JSON specifies a saved xorshift32 generator, sorted candidate selection, exact uint wrapping and frozen instance parameters. Destination is a reachable non-origin system within three shortest-route hops, with an orbital station; sightseeing instead returns to origin after an ordered route. Keep the generated route and all target identities fixed after acceptance. No route or unsatisfied equipment/hold/berth requirement means no offer.

For ordinary jobs, deadlines from acceptance are172,800/172,800/259,200 persistent game-clock seconds. Menus/pause do not advance this clock; simulated travel/services do. At exactly the deadline, confirmation succeeds. Payment is the table's base plus300 credits per required route hop, frozen at generation, once at final station handoff. Donation has no cash reward, travel or deadline. Money is integer decicredits internally. These deadline/pay values are estimates, not a standard assigned to historical stories.

| ID | Objective counts at difficulty1/2/3 | Base credit reward | Required interaction |
| --- | --- | --- | --- |
| G02 | One sealed payload | 500/750/1,000 | Deliver data, or one-tonne physical-package variant, to destination contact. |
| G03 | 1/5/10 tonnes | 750/1,500/2,500 | Supplied unique cargo or permitted procurement; partial transfers supported. |
| G05 | 1/2/3 passengers | 1,000/1,800/2,800 | Board and deliver living named passengers, with one berth each. |
| G06 | 2/3/5 ordered beacons | 1,500/2,500/4,000 | One VIP, scan each space beacon and return. |
| G07 | One named ship,0/1/2 escorts | 2,500/5,000/8,000 | Player kill before its attempted escape, then report. |
| G08 | 3/6/10 unique pirate kills | 1,800/3,500/6,000 | Solo attributed quota; unrelated/duplicate deaths excluded. |
| G12 | 1/2/3 living hostage pods | 2,200/4,000/6,500 | Disable identified ship, recover pods and return. |
| G13 | 1/2/3 tagged salvage items | 1,200/2,200/3,500 | Scoop the assigned wreck items and return. |
| G14 | 1/2/3 ordered data points | 1,200/2,400/3,800 | Continuous ship scanner downloads, then report. |
| G16 | One orbital relay | 2,500/4,500/7,000 | Destroy exact relay; collateral does not qualify. |
| G20 | 1/3/5 tonnes | 1,000/2,000/3,500 | Mine designated asteroids; market-bought material does not count. |
| G21 | One pledge | Zero | Donate500/1,500/3,000 credits or1/3/5 tonnes food; reputation+1 once. |
| G22 | 1/3/5 living evacuees/pods | 1,800/3,200/5,000 | Freeze berth or cargo-pod variant and deliver survivors. |
| G24 | 1/2/3 alien warships | 4,000/7,000/10,000 | Common classical Thargoid variant; player kills, then report. |

## Encounter bindings and failure

The JSON supplies per-profile source hull selections, estimated counts, placement, triggers, waves, scans, target escape and failure predicates. Source NPC dictionaries and O08 firing/equipment semantics supply durability, lasers, missiles and recharge; the player's155 common refit profiles do not overwrite mission NPCs. Model selection and wave composition are project choices. This common G24 variant borrows classical Thargoid warship behaviour and does not silently claim Elite Dangerous Interceptor hearts, AX equipment or pips parity.

Transport/salvage/rescue hostility uses0/1/2 Mambas according to difficulty; sabotage uses1/2/3. Quota jobs use at most three concurrently and a five-second delay between cleared waves. Assassin uses a Cobra III trader target, Sidewinder escorts and a180-second escape-attempt timer, retrying blocked jumps every five seconds. Salvage and quota encounters use their frozen destination signal; completion/removal cannot respawn them for extra rewards. Unrelated engine bounties remain ordinary game payments rather than a duplicated mission reward.

Sightseeing scans require range<=3,000 and five uninterrupted seconds; data scans require ten. Loss of range/line-of-sight resets current dwell, retaining completed points. No hidden random VIP demands or undocumented alarm mechanics are introduced in these bounded variants. Hostage release occurs once at <=25% target energy; destroying the target before that release destroys the required passengers and fails. Mining guarantees one uniquely tagged mineral tonne per designated asteroid, with2/6/10 designated asteroids. All these numerical choices are estimated and remain visible in the JSON.

Expiry, abandonment, required passenger/item loss, invalid target attribution and target escape follow each profile's explicit terminal rules. Back is not abandonment. Failure removes only mission-owned outstanding markers/entities/grants; it does not refund consumed ammunition or erase unrelated legitimate bounties. There is no extra failure fee unless a later versioned profile explicitly supplies one.

## Station handoffs, saves and validation

Apply the owner's [station-handoff contract](station-handoff-specifications.md) wherever an original source variant had a surface stage or endpoint. Record the original stage and orbital substitute in that variant's mapping; the generic template alone does not establish an unexamined campaign graph. Separately excluded Frontier/Operations missions remain disabled.

GameRuntime owns offer generation, accepted state, movement/combat outcomes and atomic acceptance/handoff/payment. Save profile revision, seed, route, deadlines, station/contact/item/passenger/target IDs, scan progress, kill IDs, encounter condition and completion transactions. A hull change preserves them, blocks if mission cargo/passengers cannot fit, and stores incompatible personal equipment without granting new missiles. Freeze payout/encounter counts across reloads.

Acceptance checks must exercise each difficulty and variant, empty/unreachable candidate sets, capacity exactly sufficient/one short, required equipment damaged/missing, Back/double confirmation, deadline equality, wrong station/contact/target, NPC kills, casualty/lost cargo, partial delivery, interrupted scans, waves once, mined versus bought provenance, donation without reward and reload at each objective boundary. Filled values make these project variants implementable; historical generator fidelity and project gameplay balance are separate validation limits.
