# Scriptable mission packs

The script engine is being implemented on `feature/scriptable-mission-engine`. The implemented verticals run authored Lua story, station, courier, humanoid passenger, timer, native classic encounter and profiled NPC/component logic without a mission-specific Swift class. It preserves schema 1 and the three bundled campaigns. This is not completion of the full physical mission-engine design, and none of the queued historical research campaigns is enabled by this example.

## Install and play the example

Choose **Commander > Install Mission Pack**, then select the [scripted courier folder](mission-packs/scripted-courier). At a main orbital station, open **Mission Contacts**, read the offer and confirm. Acceptance requires one free tonne; Back does nothing. Carry the sealed supplies to Zaonce in Galaxy 1, visit its main orbital station, and confirm delivery for 50 credits. The authored Lua module controls the branches; native code validates location, owned cargo, capacity and the balance. This original demonstration is separate from the historical mission catalogue.

The Gallery shows installed scripted missions and preserves missing-pack references, status, milestones and rendered journal entries. Browsing remains read-only. Select a supported schema 2 pack and press **T**, or choose **Game > Try Selected Mission**, to enter an isolated, seeded trial with a fresh commander and its own save directory. **Game > Restart Mission Trial** resets that scene; **Game > Return to Commander** restores the complete live game and its save destination. A failed trial restarts with Space/Return. Save, Save As, Load and Open operate within the trial namespace and preserve the live file and recent-file preferences. Window titles label trials. Unsupported and legacy entries have no trial action. Full authored historical world scenarios remain to be implemented.

## Format and interpreter contract

A schema 2 folder contains `manifest.toml` and its declared pack-local UTF-8 Lua entry module, with optional closed helper modules and pinned model files. See the [example manifest](mission-packs/scripted-courier/manifest.toml) and [module](mission-packs/scripted-courier/scripts/main.lua). The manifest declares API 2, minimum engine contract 2.0.0, identity/version, dependencies, source/license, space/orbital environments, handlers, dialogue and milestones. Unknown fields, invalid paths, linked resource components, oversized files, unsupported environments and syntax/module-initialization errors are rejected. Every declared handler must exist.

Installation snapshots and verifies the bytes, then publishes a new folder named from pack ID, version and content digest under `~/.xyzzy/elite/mission-packs/scripted`. Identical content is idempotent. Existing version folders are retained. Saved instances require their exact digest and dependency set; missing content suspends progress while retaining the cargo and event queue. Restore the original pack and select its suspended Gallery entry and press **R**, or choose **Game > Retry Selected Mission**; a changed pack is not an implicit migration.

Each named function receives `(event, world, data)` and returns `{data = a_map, commands = an_array}`. `world` is a scoped value snapshot: galaxy/system, genuine docking/main station, decicredits, free tonnes native clock values and the actual durable-commands mode. `event.kind`, `sequence` and event-specific values come from the engine. Editing either table cannot mutate native facts. Persistent data must be explicit finite values; functions, userdata, cycles, sparse/mixed-key tables, invalid UTF-8 and excessive nesting are rejected. Empty Lua tables decode as empty maps and are accepted as empty command arrays. Module globals and closures are recreated on every dispatch.

The interpreter exposes base scalar/assert/error/type/iteration helpers and numeric math, without `pairs`/`next`, metatables, catch/resume, filesystem/bytecode loaders, packages, I/O, OS, debug, string/table libraries or independent random/time. Use numeric loops and `ipairs` over ordered arrays. `tostring` accepts scalars only. VM entry, allocation, hooks, library setup, serialization and error unwinding are entirely C; no Lua error unwinds across a Swift callback. There are no interpreter pointers in game snapshots.

## Implemented native capabilities

| Capability | Current executable support |
| --- | --- |
| `scoped-campaigns-basic-v2` | Native parent-owned child instances, exact scoped receipt joins, explicit terminal policies and separate Gallery entries. |
| `partial-collections-v2` | Frozen native material quotes, real unreserved commodity handoffs and immutable repeated partial lot receipts. |
| `library-books-basic-v2` | Immutable mission-granted text books, native contents/reading/source pages, retained ownership and saved reading position. |
| `script-lua-v1` | Bounded programmable handlers, fresh environment, validated explicit data and proposals. |
| `story-v2` | Native scoped station dialogue/confirmation, journal, story milestones and terminal outcomes. |
| `economy-v2` | Signed integer decicredit debits/rewards with checked balance and per-instance operation receipts. |
| `cargo-v2` | Owned mission payload lots counted against the current hold, atomic issue/removal and receipts. |
| `calendar-clocks-v2` | Saved commander calendar, explicit epoch, native launch/travel adjustments, calendar timers and contract deadlines. |
| `commander-queries-v2` | Read-only native commander, stock, weapons, cargo, fitting and labelled common crew/accommodation queries. |
| `dialogue-choices-v2` | Repeatable station answers with immutable native receipts, compact queries, explicit answer gates and linked question screens. |
| `compound-receipts-v2` | Parent joins accept only explicitly declared sets of terminal child outcomes, including source-authorized resolved failures. |
| `exclusive-choices-v2` | Genuine orbital-station dialogue choices, immutable one-per-group receipts and matching child-branch filters. |
| `completion-receipts-v2` | Native immutable terminal receipts, exact-content child joins, acceptance/success gates and scoped completion notifications. |
| `typed-save-values-v2` | Exact integer/floating data and finite IEEE64 bits across saves, versioned unambiguous storage and bounded decoding. |
| `event-history-v2` | Bounded acknowledgement watermarks, ordered native facts and original location/clock provenance through faults, saves and retries. |
| `deterministic-plans-v2` | Versioned root/component plan identities without simulation RNG draws; existing plans retain their original IDs and condition. |
| `world-resource-jobs-v2` | Independent loaded-world station/actor jobs, actual owner death cancellation, scoped maintenance/deployment rights and saved pulses/retry. |
| `pulse-counters-v2` | Named native pulse counters, enabled state, next-callback zero reset, nominal/actual firing stamps and bounded saved values. |
| `local-flight-clocks-v2` | Saved local/flight clocks, one-shot/fixed-delay/skipped-interval named timers and actual fired pulses. |
| `profiled-encounters-v2` | Pinned measured NPC/component models, explicit zero-preserving fits, native bounded steering and laser/plasma collisions, saved projectiles. |
| `pack-modules-v2` | Closed named Lua helper imports with exact file snapshots, shared dispatch budgets and fresh per-dispatch state. |
| `classic-encounters-v2` | Full-cohort admission for declared classic NPCs, persistent world identities and actual destruction/removal facts. |
| `charter-passengers-v2` | Actual common humanoid cabin fit, owned passengers and orbital-station delivery receipts. |
| `owned-equipment-v2` | Unique native gear, hull transfer/surplus storage/refit, scoped quest issue/return/release, true consumption and return gates. |
| `contracts-basic-v2` | Saved main-orbital offers, explicit review/decline/accept, distinct repeatable job IDs, deposits and frozen success/failure settlement terms. |
| `gallery-basic-v2` | Isolated player-facing trials, validated starting loadout, native launches, restart/return and separate saves. |
| `durable-commands-v2` | Bound-writer publication before command effects, atomic failure/retry and post-physics script transactions. |

Required capabilities outside this set keep a valid pack unavailable. In particular `world-clocks-v1` from the design is not advertised: transit and full source-specific station/care services are not implemented yet. No physical kill objective can be proved by a story milestone, contact, role name or installed pack.

Current events are `mission.accepted`, `station.docked`, `station.undocked`, `system.entered`, `contact.requested`, `dialogue.confirmed`, `timer.fired` and reserved `mission.abandoned`. Classic encounter packs additionally receive `encounter.admitted`, `encounter.pending`, `actor.destroyed` and `actor.removed`. Dock/location events are observed after native simulation/input changes. No public script API manufactures physical destruction, wormhole, passenger or equipment events.

| Command | Fields after `op` | Native checks |
| --- | --- | --- |
| `credits` | `id`, signed integer `amount` | Declared economy capability, once-only operation, balance 0-4294967295 decicredits. |
| `payload.add` / `payload.remove` | `id`, `key`, positive integer `amount` | Declared cargo capability, owned lot, final whole-batch hold fit, once-only operation. |
| `milestone.ensure` | zero-based `index` | Declared story milestone; idempotent. These are story milestones, not physical-objective receipts. |
| `journal.append` | `text` | Bounded rendered text and journal count. |
| `dialogue.offer` | declared dialogue `id` | Actual main orbital station; pins instance, location and revision token. |
| `dialogue.commit` | `id`, native event `token` | Actual matching confirmation, current location/revision and offer. Back cannot issue this event. |
| `timer.ensure` | `id`, `domain`, `after`, `interval`, `policy` | Local/flight/calendar domain with the declared calendar capability, finite bounds, `once`/`delay`/`skip`, saved native due/pulse state. |
| `timer.cancel` | `id` | Removes this instance's timer only. |
| `encounter.ensure` | declared encounter `id` | Saved identity plan, exact location/profile, whole-cohort capacity and clear placements before admission. |
| `passengers.board` / `passengers.deliver` | `id`, declared `party` | Actual station/location, fitted compatible cabin, stable person ownership and once-only transfer. |
| `mission.finish` | `outcome` | `complete` requires every milestone, required passenger delivery and declared required destruction encounter; `failed`/`abandoned` are terminal. Place this last. |

Commands and explicit data form one staged commander transaction. The desktop runtime writes it durably before publishing effects; a memory-only embedding must opt into a save destination, and packs can require `durable-commands-v2`. See [transaction guarantees and recovery](DURABLE-MISSION-TRANSACTIONS.md). An invalid command, unknown field, denied balance/hold, stale confirmation or execution fault discards the proposal. Already accepted instances suspend with their original data/property and unacknowledged event; initial acceptance fails without creating an instance. Subsequent events cannot revive or repay a terminal instance. A source-authorized failed payment can precede the terminal command in the same batch. Personal equipment storage and passenger custody are not payload substitutes. See [common charter accommodation](PASSENGER-ACCOMMODATION.md) for fitting, storage controls, source limits and the passenger example.

Local time continues in loaded unpaused docked panels and handoffs, freezes in Help/Gallery/route planning/explicit pause, and advances by the native capped tick. Flight time follows actual native flight simulation, including charts that leave flight running. Inactive domains cannot fire already-due timers; opening the Gallery does not process them. A skipped timer fires once after a late tick and schedules the next original interval; it does not replay missed pulses. Transit progression remains unavailable. Resource-owned jobs have their own explicitly defined loaded-world clock; see below. The commander calendar is initialized before any mission acceptance; legacy import records an explicit migration origin without adding offline time.

## Actual classic encounters

The [scripted patrol](mission-packs/scripted-patrol) is a second original demonstration: accept at a station, launch at Lave, fight the two actual assigned raiders, dock through the native flight controls and confirm your report. The acceptance test uses real lasers and automatic docking. Ordinary kill/bounty/Right on Commander behavior remains in native combat; an allied/environmental kill can satisfy the owned destruction objective without granting a player bounty.

Declare `[[encounters]]` with `id`, `galaxy`, `system`, `profile` and an `actors` array. Each actor declares an exact alias, native `hull`, station-relative `x/y/z` and `hostile`. The supported profile is **classic-local-freeze-v1**: existing native Cobra/Viper/Sidewinder/Constrictor/Thargoid/Thargon NPC behavior and fitting, with unloaded/docked scenes frozen. This is not an Oolite physics or AI adapter. No source NPC zeros are replaced with player starter equipment.

The manifest mission's optional `requiredDestructionEncounters` lists cohorts that must actually be admitted and entirely destroyed before successful completion. Lua reads scoped `world.encounters` facts; copying an event, matching a role or declaring a milestone cannot create a native tombstone. The `encounter.ensure` result arrives later as a native event. Obstructed/over-capacity deployment retains its prepared identities and returns pending; no partial fleet appears. Subsequent commands in the same transaction can still roll back the entire staged admission.

Actors keep a stable world UUID separate from reusable scene integer IDs. Main-station-relative canonical position, orientation, energy and spent stock persist through genuine docking/launch/system transitions and saves. The main station reference follows the same actual player frame even when its visible mesh is culled, including in-system jumps. Returning actors reproject from their stored world position; they are not healed, restocked or moved into range. Leaving the loaded region records removal rather than destruction. Same-frame fatal hits settle before scene unload and ordinary bounties remain once-only.

The native capacity test admits 82 actual classic roots. It is a generic capacity/identity fixture, **not Maenes acceptance**: the latter still requires its actual custom fits, components/turrets, crew/custody, AI/transit, all clock domains, station jobs and source-law adapters. Keep full historical packs gated on those capabilities.

## Saves and bounds

Normal commanders without scripted instances, owned equipment, owned cabins or saved contract boards retain the existing single JSON format. Scripted commanders publish a small JSON generation pointer plus a sibling `.missions` directory. Each immutable generation contains hashed `commander.json`, `missions.json`, `world.json` and `contracts.json`. All new chunks are written before the pointer is atomically replaced; earlier generations remain recoverable. Load validates every chunk and the complete candidate before replacing actor state. No ordinary docking, reward, auto-trade or Lua constructor callbacks replay during scripted restore. The reader retains formats 2 through 12; writers publish format 13 with an explicit commander/gallery scope tag, which older readers reject rather than silently discarding actor or passenger data. Preserve both the pointer and its sidecar when copying a scripted save.

The current format-13 world chunk preserves native RNG/tactics/spawn/weapon/ECM counters, temperature/altitude, exact solar bodies/kinds/radii, fractional scoop fuel and scoop-controller state, an offscreen station reference, stable owned encounter records, local bodies/market, location/docking/view, energy/shields/heat, speed/time, selected system, jump countdown and next body ID. Full source-profile AI/controller/transit/care/campaign world persistence remains part of subsequent physical implementation; this first chunk must not be used as proof that all researched battle state can be restored. Publication currently runs synchronously inside GameRuntime, which prevents actor reentrancy during the write. Automatic Confirm and post-physics script publication use that synchronous barrier. Background writer scheduling, bounded input backpressure and explicit migrations remain required by the full design.

Initial quotas are 50000 VM instructions (1000-instruction hooks), 8 MiB heap, 32 MiB allocation work, 512 KiB proposal output, 256 KiB explicit data, 256 commands, depth 32 and 16384 exchanged values. Collections, journals, receipts, instances and pending events have native limits. These are bounded initial implementation limits, not permission to truncate researched encounter counts. VM faults cannot publish partial output.

The [24-requirement status map](SCRIPTABLE-MISSION-STATUS.json) records partial and unsupported groups separately.

## Validation and remaining implementation

The [validated checkpoint](SCRIPTABLE-MISSION-VALIDATION.json) passes 516 tests in each coverage/thread/address lane, 94.41% maintained coverage and zero native diagnostic leaks.

Run `make script-missions-check` for the thirteen authored examples, `make test` for behavior and `make ci` for repository gates. Tests cover script execution, quota faults, invalid output, initial acceptance rollback, whole-batch cargo/economy rollback, stale/Back/valid Confirm, terminal reward replay, missing content/cargo preservation, local timer skips, isolated trials, old saves, immutable generations and corrupt/failed saves. The maintained C shim is included in coverage; only unmodified third-party Lua is excluded from the maintained-code percentage and Sonar source scope. Compiled Lua still runs under sanitizers and leak checks.

The full design additionally requires actual owned fleets/components and admission, native AI/docking/wormholes/weapons/death objectives, all source clock domains and persistent station jobs, people/life support/crew/berths, full source-specific gear condition/modification adapters, full source station/contract adapters and world services, compound campaign receipts, complete physical save/migration/replay services, deterministic plans, full Gallery scenes/tools and native Maenes/finance/RRS acceptance. These remain unsupported, with no historical mission rewritten into a courier to bypass them.

## Shared release integration

Main `34790e3` is integrated on this isolated branch, retaining the detailed hulls/materials, Liberator, startup/profit/controls, navigation and solar flight. Physical saves use a separate solar snapshot adapter; restoring does not run celestial constructors or reset heat/fuel. Startup keeps the native title at animation time zero while the saved physical scene freezes. Continue restores the saved simulation time; saving at the title writes that physical time. Earlier physical saves without solar data keep an empty solar scene until a genuine launch or arrival. Full autopilot/spin/audio/controller persistence is still outstanding.

## Basic trial presets

A schema 2 pack may declare `[trial]` with exactly `ship`, `galaxy`, `system`, `credits`, `cabins` and `flight`; it must require `gallery-basic-v2`. Credits are integer decicredits. Ships must be known flyable hulls; galaxies use 0-7 and original systems use 0-255. Cabins must fit the actual hull and be affordable from the trial balance. Each is purchased through the real cabin service before acceptance; no free passenger seats or fictional objective receipts are injected. `flight = true` performs a real native launch after acceptance. Undeclared presets use the ordinary starting commander at docked Lave. The passenger example seeds one actual cabin and boards its real passenger.

Trials use a new save directory and cannot install content. New scope-tagged saves are rejected when opened in the other mode, including when copied into the other directory; older formats have no origin tag. This is a save-format consistency check, not a signature against deliberate file editing. Namespace and generation path checks apply independently. File dialogs and controls carry a presentation identity so delayed input from another game is rejected. Audio/speech avoid comparing unrelated scenes or replaying the restored commander's old messages.

Deterministic script faults retain pending facts and save their suspension without publishing rejected actions. Retry first saves the unsuspended state, then reprocesses pending facts transactionally. Unavailable exact content or another failed native check remains suspended. Filesystem publication failures preserve the live state for explicit retry rather than reporting a saved result.

## Owned equipment, storage and quest loans

Hull exchange builds a pure compatible-fit proposal. Existing lasers, missile rounds, modules and tanks have persistent item IDs. Legacy inventory imports actual fitted mounts and counts; old laser-name caches do not manufacture additional guns. Current compatible equipment takes priority; incompatible or excess equipment goes to persistent commander storage. Strongest currently fitted tier wins when legacy saves carry redundant computer/energy/shield tiers. Empty cabins may be stored; occupied/reserved/extra-crew cabins and actual freight must fit. A later exchange refits compatible stored items without purchase or ammunition replenishment. Spare fuel, invalid routes and insufficient real hold still block confirmation. The comparison shows actual projected fitted guns, loaded missiles and spare equipment units; both previews retain the existing shared orientation.

At a main orbital station, select an equipment row and press **S** to store a fitted item, or **R** to refit an owned stored item. Laser refitting uses the selected facing. Stored equipment is commander property, distinct from ship cargo and people. Consumables remove the actual fitted identity; stored rounds/devices are untouched. Replacing an owned laser or computer stores its predecessor. Empty cabin controls remain separate. Fitting uses the selected common equipment budget and its documented estimates. Newly issued native gear starts at standard working condition; condition/modification metadata is preserved in storage, but nonstandard metadata cannot be refitted until its native controller is supported.

The [equipment-loan example](mission-packs/scripted-equipment) borrows a real ECM unit and returns that original unit at Zaonce. It is an optional original demonstration, not a historical mission. Its acceptance test travels through native hyperspace, uses native automatic docking and confirms the real return/reward at the station.

A pack declares `[[equipment]]` with `id`, known native `name`, `quantity` (1-32), `loan` (Boolean), optional laser `mount` and optional `returnPolicy` (`all`, the default, or `remaining`). At most 64 declarations and 128 total items are supported. `requiredEquipmentReturns` in `[mission]` names native return receipts that completion requires. Passenger cabins and liquid fuel are not equipment resources. Loans retain their issuer/resource/owner through storage, hull exchanges and saves. Missing exact content suspends active instances immediately without deleting property.

| Command | Fields after `op` | Native checks |
| --- | --- | --- |
| `gear.issue` | `id`, `gear`, optional Boolean `fit` (default false) | Declared resource; one issue per instance/resource, deterministic IDs, real slots/units when fitting, no constructor refill. |
| `gear.store` / `gear.refit` | `id`, `gear`, zero-based `index`, optional laser `mount` | Exact original item belonging to this instance/resource; genuine main orbital station and compatible actual fit. |
| `gear.return` | `id`, `gear` | Original issued identities; substitutes do not count. `all` refuses spent/missing items; `remaining` settles only surviving originals and separately reports genuinely consumed items. |
| `gear.release` | `id`, `gear` | Only the issuer's own loan can become player property; this explicit release cannot satisfy a required return. |

All commands require `owned-equipment-v2`, an active instance and the actual main orbital station. They participate in the whole-command transaction and durable publication barrier. Completion requires every outstanding loan to have been returned or explicitly released, plus every declared required return. Story flags and dialogue acknowledgment cannot manufacture a return.

Native events are `ship.changed`, `equipment.changed`, `gear.consumed`, `equipment.issued`, `equipment.returned` and `equipment.released`; subscribing requires the capability. Result events carry actual identities; return/release `items` excludes spent goods and `consumed` is separate. `world.fitted_equipment` / `stored_equipment` are name/count maps; `free_equipment_units` is actual spare common fitting space. `world.issued_equipment` is scoped to the current instance with status, loan, remaining/consumed counts and original IDs. Source-specific damaged/modded fitting, occupied pods, station stock/broker movement, care/world services and historical acceptance remain gated under the full design.

## Saved station contracts

Install the [station sample contract example](mission-packs/scripted-contracts) and choose **Game > Station Contracts** at a main orbital station. Arrows select; Return or a click opens the briefing. Left/Right selects Accept, Decline or Back, with Back selected initially. Reading, Back, Help, Save and reload do not accept or start a deadline. Decline removes only that offer from its saved snapshot. Offer and briefing lists scroll. Blocked offers retain their real fit reason. Active assignments remain visible across stations and in the Mission Gallery. Accepted job instances have separate Gallery entries and retain their original terms, offering station, payload and identity. Template trials generate and accept a real first offer in an isolated namespace; `[trial].offer` can select another generated position. Saved job checkpoint trials remain a richer Gallery requirement.

The original example offers nearby sample runs with real owned tonnes and a deposit. It requires an actual direct jump and enough fuel, physical hold and equipment space. Native hyperspace, automatic docking, station handoff, on-time settlement, late failed settlement, separate repeated instances and cancellation are exercised in acceptance tests. To cancel this example, return to its original offering station and use Mission Contacts to hand back the actual samples and forfeit the deposit; Back preserves the accepted job. This is a generic main-station demonstration, not RRS or historical mission implementation.

A pack with `[board]` becomes a repeatable contract provider instead of an ordinary single Mission Contacts enrolment. Declare `id`, `title`, `generator`, `clock`, optional `refreshSeconds` (default3600) and optional local `exclusiveGroup` (default board ID). Require `contracts-basic-v2` and `local-flight-clocks-v2`; durable production providers should require `durable-commands-v2`. Implemented board domains are `local`, `flight` and `calendar` (with `calendar-clocks-v2`). Transit still requires the unavailable full `world-clocks-v1` capability. Main orbital identity is explicit and independent of display names. RRS waystations/headquarters, their distinct capabilities/roles and geometry remain required under full `contracts-v1`; this basic provider does not manufacture them.

The generator is a declared, validated Lua function using the same bounded fresh VM. It receives `board.generate`, a read-only world and empty data. Return `{data={offers={...}}, commands={}}`; generation cannot pay, spawn, reserve, accept or issue any command. World fields include actual `station_id`, `board_revision`, 64 deterministic unsigned32 `offer_draws` and current-galaxy known ordinary `destinations` (system/name/distance/economy/government/zero-based technology). The stream is separate from native combat and existing mission streams. A board's station/provider/digest/time generation, seed and decisions are saved before publication. Opening, refresh, Back, refuel or hull changes in the same generation do not reroll them. At most128 saved provider/station snapshots and16 offers each are supported.

Each offer requires exactly these fields: `key`, `title`, `briefing`, `destination_galaxy`, `destination_system`, integer decicredit `reward`, `deposit`, `failure_reward`, Boolean `refund_on_failure`, nonnegative `duration` (zero means no deadline) and map `parameters` (4096 encoded bytes maximum). Keys are unique within a board; destinations use galaxies0-7/systems0-255. Native IDs are derived from provider/digest/station/generation/key, never supplied by Lua. A stale generation, declined offer, unavailable exact content, insufficient actual funds, occupied provider group or failed native acceptance/fit refuses the entire action. Source exclusivity is namespaced by pack ID. Accepted work is independent of a refreshed board.

Acceptance freezes the offer in its new instance, debits the deposit once, anchors the declared duration to the actual selected clock and calls the ordinary Lua accepted handler. Time spent previewing is excluded. Repeating the same confirmation returns the existing receipt and cannot take another deposit. A cached quote is bound to its commander context/resources; elapsed ordinary time alone does not invalidate it, while changed resources or an hour boundary can. Standard contract fitting uses physical hold/equipment space even with the legacy unlimited-cargo switch. The existing XYZZY free maximum refit retains its explicit legacy cargo/outfit behaviour when no physical cabins or contract obligations are aboard; storage preserves replaced personal gear.

`world.contract` is an authoritative scoped snapshot: offer/station IDs, destination, original parameters, reward/deposit, accepted time, deadline and actual deadline-passed state. The snapshot also reports current same-galaxy `distance_ly`; common `world.jump_range_ly` is actual available jump range and `station_id` is the genuine docked main station or null. Lua data edits cannot change frozen terms. A native `contract-deadline` timer produces the real pulse; scripts choose their stated failure/return policy. Native completion refuses success after a real deadline even if Lua ignores the pulse.

On `mission.finish`, native settlement pays exactly the frozen reward plus deposit for success, or the frozen failure reward plus the declared failure refund. Abandonment forfeits the deposit and pays zero. Each settlement records its actual outcome, amount and clock stamp once; a legitimate full-payment failed outcome remains failed. Failed writes publish no deposit/cargo/acceptance/return/payment changes. Scope-specific late care, escrow/loans beyond these terms, actual commodity-lot/pod services, RRS eligibility/variant scheduling, shared contacts/reputation and independent world jobs remain full-design work.

Format9 retains contract snapshots in a hashed `contracts.json` generation chunk. Combined validation joins accepted board receipts to the exact frozen job, identity, source version and settlement terms. Missing/tampered/linked chunks refuse the candidate without replacing live state. Board selection and briefing state are saved with the world; restoration can validate isolated quotes but never applies an acceptance/spawn/reward constructor to the live world.

## Profiled NPCs, licensed models and physical weapons

`profiled-encounters-v2` adds a bounded native project adapter, `profiled-local-freeze-v1`, for distinct owned NPC fits and solid components. The [optional original skirmish](mission-packs/profiled-skirmish) is an installable example and isolated Gallery trial. Its figures and original models are demonstration values, not historical ship specifications or a claim of full Oolite/Maenes parity. The broad `world-actors-v1`, `flight-ai-v1` and `combat-events-v1` gates remain unavailable until source AI, travel, law and acceptance are complete.

Declare up to64 `[[npcs]]` entries with unique local `id`, `name`, `source`, `basis`, `model`, positive `scale`/`energy`, nonnegative `recharge`, `speed`, `acceleration`, `pitch`, `yaw`, `roll`, `missiles`, `fuel`, Boolean `ecm` and integer-decicredit `bounty`. This adapter uses metres, metres per second, metres per second squared, radians, seconds and native energy units. NPC energy is one actual pool; it does not import the player's shields or minimum equipment. Source zero fuel/missiles/ECM remain zero. Select an NPC using `npc="local-id"` in an encounter actor, without a classic `hull`. Classic packs retain their original profile.

A `model` is either `catalogue:SHnnn` measured raw catalogue geometry, or `asset:local-id`. `[[models]]` declares `id`, pack-relative JSON `path`, exact lowercase SHA-256 `sha256`, `source` and `license`. The JSON uses the existing `ShipDesign` vertex/face/detail/material schema and matching provenance. Each file is at most256KiB, with at most4096 vertices,8192 faces,64 indices per face,8192 details and256 materials. Up to32 declared model files are supported; links and nonregular files are refused. Catalogue geometry and declared asset bytes participate in the pack digest. Installation verifies/copies exact bytes. A catalogue model supplies geometry alone: player performance, cargo, accommodation and other fits remain unchanged. No texture download or arbitrary file loader is available.

`[[npcs.components]]` has `id`, `model`, positive `scale`, XYZ `position`, right-handed orthonormal `orientation` (`x/y/z` XYZ axes), positive `energy`, Boolean `solid` and optional `weapons`. Components have engine-issued stable UUIDs, their own damage/guns, and preserve parent scale and transforms. Destroying a component disables its guns and removes its visible/collision geometry; it never supplies a hull tombstone or player bounty. Assemblies retain per-face materials and use one face-depth sort. Whole encounter placement reserves actual root/component bounds, the commander hull and native capacity before admission. Each root and live solid component consumes one of1024 native world units; projectiles consume units too. Obstructed/full requests retain the complete plan without shrinking, cloning or restocking it.

`[[npcs.lasers]]` and `[[npcs.components.weapons]]` declare local `id`, `kind` (`laser` or `plasma`), XYZ `muzzle`, unit XYZ `direction`, maximum aiming `arc` in radians, `damage`, `range`, `interval`, energy cost `energy`, `heat`, `cooling` and `maximumHeat`. Optional `trackingRate` bounds native barrel aiming in radians/second; zero or absent keeps the barrel fixed. Optional `colour` is opaque RGBA. Plasma additionally requires positive `projectileSpeed`, `lifetime`, `collisionRadius` and nonnegative `collisionDelay` less than lifetime. Lasers have none of those projectile fields. At most16 root guns,32 components and8 guns per component are supported. A facing is not a fitted gun.

Native shots enforce current direction, range, energy, heat, cooldown, live components and whole available world capacity. Lasers hit the first actual mesh collider; plasma uses a swept sphere against transformed triangles, including edge/corner contact after its collision delay, and expires at its real lifetime. The player collider uses the selected hull's measured/native geometry. Intervening ordinary craft/components can take real damage; main station protection remains in place. Source laser/gun values do not overwrite player mechanics. The player's original classic targeting behaviour remains for classic-only shots; shooting a profiled target uses actual geometry and intervening colliders. Plasma is rendered as emissive geometry and is neither destroyed nor credited as a missile by ECM. Profiled missile firing, source missile variants/blast/ECM accuracy and full law/AI controllers remain unsupported; declaring initial missile stock does not claim those behaviours are implemented.

Issue a typed request such as `{op='actor.intent', id='rendezvous-1', encounter='fleet', actor='escort', mode='follow', target='leader', offset={0,0,-500}, speed=0.5, tolerance=30}`. Modes are `hold`, `approach`, `follow`, `attack` and `flee`. Approach offsets are canonical main-station coordinates; follow offsets are target model coordinates. Other directed modes target `player` or one distinct owned actor alias. `speed` is a fraction0-1 of the declared maximum. Reusing an action `id` is read-only; use a new ID for a new decision. A request for a foreign/ambiguous target, unavailable NPC or malformed intent is rejected atomically. Native steering uses the pitch/yaw and acceleration envelopes; this adapter holds roll. NPC-first docking, scoop, escape, wormhole/transit, formation avoidance, source think/accuracy/RNG constructors and actor adoption require the later flight/world capabilities.

`actor.intent.accepted` is a request receipt, distinct from native `actor.arrived` and `actor.target.lost`. `actor.damaged`, `component.destroyed` and `weapon.fired` carry actual owned IDs and engine facts; a fired projectile is not a hit/death receipt. Ordinary destruction rules and native milestone gates remain authoritative. Scoped actor snapshots include canonical position, velocity, NPC name/source/basis, fuel, gun heat/cooldowns, shots, intent status and component identities/condition. `world.player` exposes the actual commander pose in the same station frame plus hull, energy/shields/heat. Lua decision procedures can use ordinary bounded local timers; no render callback runs Lua.

Format9 saves immutable model hashes/geometry once, per-actor fit, component IDs/damage, current velocity/intent, ammunition, energy, heat, cooldowns and barrel aiming. Live projectiles retain deterministic owner/shot identities, velocity, age, delay, damage and lifetime. Camera transforms convert vectors to the saved station frame. Dock/unload freezes this selected local profile; launch/reentry restores the same condition and unexpired shots without constructors or replenishment. Readers accept formats2-8; older builds reject new format9 rather than treating custom actors/projectiles as ordinary Cobra/missile bodies. Native saves validate model references, unique physical IDs, exact actor records and projectile ownership. These additions are a bounded physical milestone, not full historical mission enablement.

## Reusable pack-local Lua modules

Declare `pack-modules-v2` and up to16 `[[modules]]` records, each with a unique local `id` and canonical relative `.lua` `path`. The original `module` field still selects the entry script. Module paths cannot duplicate the entry or any model path. See the [modular skirmish manifest](mission-packs/profiled-skirmish/manifest.toml), [entry](mission-packs/profiled-skirmish/scripts/main.lua) and [shared procedures](mission-packs/profiled-skirmish/scripts/skirmish.lua).

The entry and its helpers can call the provided local `require('declared-id')`. It lazily evaluates that declared text file and returns its table; repeated imports in one dispatch return the same table. Factories exist before entry initialization, so declared file order is not a dependency order. Cycles, unknown/non-string imports, non-table exports and syntax errors produce readable faults. Unused helper text is still parsed and fingerprinted. Imported helpers can provide procedures, generators, handlers and bounded data tables; the entry must return the named handler table expected by the native API.

This loader has no package search path, external/native modules, bytecode loader, filesystem access, independent RNG, catch/resume or retained VM. All module initialization and handler work shares the protected C VM's instruction/allocation/output limits. The complete compiled script set, including its small generated closed-loader wrapper, must fit256KiB. Persistent state remains the explicit `data` map; module-local tables/closures reset on the next dispatch.

Every declared helper's exact bytes enter the content digest and immutable installation. Installation preserves the authored entry/helpers rather than writing generated wrappers into the source folder. The loaded pack's source/model/resource snapshots are immutable Swift values. Editing any helper creates different content and cannot silently replace the version a saved instance needs. Cross-pack dependency declarations still identify installed exact versions; they do not expose another pack's files through `require`. Single-file packs keep their original bytes/digests and need no module capability. Explicit version selection, content migrations and complete author replay tools remain later engine work.

## Commander calendar and native pulse counters

The selected profile is `project-oolite-calendar-v1`, with project epoch zero and day `floor(calendar_seconds / 86400)`. Loaded unpaused play advances at the native capped tick; title/Continue waiting, Help, Gallery, contracts, mission confirmation and docked inspection panels freeze it. Normal status/trading/equipment time continues. No real wall-clock/offline delta is applied. Launch from a station adds 600 calendar seconds once. An admitted ordinary hyperspace journey adds `3600 * distance * distance` on genuine arrival. The selected source distance first truncates integer half-Y, then truncates the square root and multiplies by 0.4. This metric is separate from the unchanged native fuel/range distance. Galactic drive adds no ordinary journey charge. Native motion, heat, scooping, local/flight clocks and celestial state do not advance by travel adjustments.

Admission saves the actual origin, destination, source distance, native fuel debit and operation number. Chart inspection cannot retarget a journey; explicit navigation cancellation/manual destination change and docking clear its admission without charging travel. Saved countdowns resume after Continue and charge once. Old untracked countdowns remain explicitly labelled as legacy rather than guessing a historical travel debit. Legacy flat commanders remain compatible with their existing docked-restore behavior. Hull exchanges and Gallery browsing preserve the live calendar; a trial receives its own epoch. Format 10 requires the validated ledger and countdown/admission consistency.

The selected source rules come from pinned [Oolite commit 574ca848, legacy_random.h](https://github.com/OoliteProject/oolite/blob/574ca848c91a067178416216523e8d09c1e9282a/src/Core/legacy_random.h#L154) and [PlayerEntity.m](https://github.com/OoliteProject/oolite/blob/574ca848c91a067178416216523e8d09c1e9282a/src/Core/Entities/PlayerEntity.m#L6466). Epoch, panel policy and bounded migration are labelled project decisions. A repeating timer at the clock ceiling reports its last actual pulse and a saved `clock_exhausted` flag, preventing an invalid future due stamp or repeated callbacks at frozen time. Equipment service, fines, escape-pod adjustments and historical loans are not implemented by this calendar capability.

The [calendar contract example](mission-packs/calendar-contracts) uses real calendar board revisions and a frozen 24-hour acceptance deadline, including launch and travel. Expiry does not remove owned cargo or automatically pay; its authored station handoff settles the frozen failed terms. The original local-clock contract example remains separate.

With `pulse-counters-v2`, `timer.counter.ensure` takes timer `id`, local `name` and optional `enabled`; an existing counter is not reset. `timer.counter.enable` requires a Boolean. `timer.counter.reset` enables the counter and queues a reset: the next actual callback reports zero, then following actual callbacks report 1, 2 and so on. The timer must already exist. Counters are native saved state, limited to 16 per timer and one billion actual pulses. A skipped interval fires once; missed callbacks never fabricate counter progress. `timer.fired` provides `counters`, `reset_counters`, `has_been_run`, `due` and `fired_at`; `world.timers` includes the saved nominal/actual stamps and counter enabled/reset state. These primitives do not establish complete Maenes/world-job acceptance.

## Resource-owned station and actor jobs

`world-resource-jobs-v2` adds separately saved services owned by an actual station or admitted ship. The origin mission identifies the pinned content and controlled encounter ledger; it owns no continuing reward right. A completed, failed or abandoned mission may retain a running job without its outcome, milestones, balance or cargo being revived. The Gallery briefing displays ongoing service state and its last journal entry. Retry can resume a suspended service attached to a terminal mission without restarting that mission.

Declare `[[worldJobs]]` with `id`, player-facing `title`, named `handler`, `owner` (`station` or `actor`), `galaxy`, `system`, `firstDue`, `interval` and `policy` (`once`, `delay`, `skip`). Actor owners additionally require an exact declared `encounter` and `actor`. Optional `counters` declares up to16 native pulse names; `controlledEncounters` grants deployment and repair rights over exact declared cohorts in that same world. Require both `world-resource-jobs-v2` and `pulse-counters-v2`. Up to32 definitions per pack and64 saved jobs are supported. These are explicit admission limits; deployment never truncates a declared fleet.

The active mission command `world.job.ensure` takes only a declared `id`. It binds the actual existing main station or physically present admitted actor, creating its identity once. Prepared/foreign/absent actors cannot own a job. Repeating an ensure returns the existing job without restarting its data, time, pulses or terminal status. A station tombstone prevents recreating its service. Tracked station energy survives docking/launch and genuine system changes; a destroyed station cannot be regenerated by launch, arrival or reload.

The selected basic profile advances each job's own loaded-world elapsed time by capped native ticks while its actual system is loaded and unpaused, including read-only panels and docked time. Title/demo/game-over and explicit pause freeze it. Unloaded systems and unavailable exact content freeze it without offline catch-up. Parent commanders held outside an isolated Gallery trial do not run. Each native pulse saves nominal due, actual firing time, counters and its own pending sequence before command evaluation. Skipped intervals do not create missed pulses. Format11 retains the service, owner, condition/tombstone, exact definition, explicit data and pending pulse. Missing content suspends even a completed parent mission's active services.

The named job handler receives `(event, world, data)` with independent explicit job data, `event.kind='world.job.pulse'`, engine sequence, actual `resource_id`, due/fired stamps, pulse/counters and scoped native encounter facts. `world.job` contains service identity/status/elapsed and `world.parent_outcome` is read-only. Its entire command batch is staged and durably published before effects. A rejected batch preserves the actual physics already settled, retains its original pending pulse and changes neither returned data nor repair/deployment effects. Explicit retry processes that pending pulse once.

| Job command | Fields after `op` | Native rights |
| --- | --- | --- |
| `encounter.ensure` | declared `id` | Only a declared controlled cohort in the owner's actual world, using normal complete-cohort native admission and saved identity plans; unavailable space yields pending. |
| `actor.repair` | `id`, `encounter`, `actor`, finite positive `amount` | Actual living measured owned NPC, owner itself or controlled cohort, unchanged stock/guns/crew and native maximum energy; once-only repair receipt. Fatal hulls and destroyed components cannot be revived. |
| `job.counter.reset` | declared `name` | Queue native next-callback zero reset. |
| `job.counter.enable` | declared `name`, Boolean `enabled` | Change this job's existing counter only. |
| `job.journal.append` | bounded `text` | Service journal only. |
| `job.finish` | none | Complete this service only; place last in a batch. |

Jobs cannot issue credits, mission outcomes/milestones/dialogue, cargo, people or equipment operations. Actual owner destruction cancels its active jobs, discards pending actions and records the cancellation; it grants no player kill or bounty. Alive scene removal is not destruction. Controlled encounters still use the selected classic/profiled local adapters and their clear-placement/capacity restrictions. Full source main-station geometry/law, large-world grid layouts/replacement generations, people-care resources, transit, service finances and complete Maenes/RRS acceptance remain unavailable; `world-clocks-v1` stays gated.

The optional [station service example](mission-packs/station-maintenance) completes a no-payment authorization at Lave, then uses a separate station-owned job to request two actual friendly training ships. While docked it retains a pending native deployment plan. Launching permits genuine admission; only the subsequent native snapshot can confirm deployment and complete the service. Its Gallery trial uses a fresh commander and the same native path. It is an original demonstration, not a substitute for a historical mission.

## Native event history and provenance

`event-history-v2` preserves `event.instance_id` and optional `event.context`, separate from the current scoped `world` query. The native context captures actual galaxy/system, docking/main-station status, instance revision, native frame/local/flight/calendar/transit stamps, calendar day and available station-relative player position when the event is emitted. A delayed callback can read the original fact and current situation without treating reload/retry time as the original occurrence. Frame time is the existing native frame counter; it is separate from the explicit script clock domains. Native `kind`, `sequence`, `instance_id` and `context` cannot be overwritten by event-specific values or by modifying the Lua argument table.

Pending envelopes retain their original contexts across publication faults and saved reloads. Older facts have unknown provenance (`event.context` is nil); load does not invent a location or timestamp. Format12 requires ordered unique pending sequences and bounded, consistent native contexts/revisions. Suspended earlier events cannot be skipped to acknowledge later events. Replayed acknowledged facts are removed without running their handlers again.

New acknowledgements use a native high-water mark rather than an ever-growing set. Legacy sets remain readable and collapse on the next actual acknowledgement, without replaying their handlers or constructors. A test runs5000 actual timer callbacks, saves and reloads with the acknowledgement set empty and count/pulses preserved. Explicit data, journals, action receipts and other collections retain their documented bounds; this does not grant unlimited financial receipts or advertise the full archival/replay/world-epoch design.

`deterministic-plans-v2` makes new root identities from a versioned namespace plus the actual origin-instance ID, pinned pack digest, declared encounter and alias; solid component IDs additionally bind their actual root and component alias. Identical preparations therefore retain the same proposed IDs after a denied transaction without drawing simulation randomness. Different origins cannot alias the same models. Existing prepared/admitted records retain their original IDs, energy, component condition and stock even when they predate this identity scheme. The actual admission/death ledger remains authoritative: a predictable planned ID is not a spawned ship or destruction receipt. Projectile, station/job and contract identity namespaces keep their previous values.

Contract quotes now compare actual commander property and assignments while excluding autonomous timer/event/journal/AI/world-job progress and legacy elapsed clocks. They retain hull, fit/storage, cargo/payloads, people/berths, funds, station/offer terms, assignment outcomes, milestones, scoped equipment custody and frozen contracts. Confirm still evaluates the current native acceptance and hourly revision; real resource changes or newly ineligible conditions are refused. A test reviews a frozen offer while native mission timers and a station job prepare a patrol, then accepts the original terms without losing that progress. Existing stale-hour, fitting, balance and once-only acceptance tests remain required.

Full durable world IDs/epochs, complete source causes, archival/replay services and source-profile RNG/constructors remain part of the unimplemented full design. The new event and identity capabilities do not enable queued historical campaigns.

## Exact script-value storage and bounded loading

`typed-save-values-v2` preserves the distinction between signed64-bit integers and finite floating-point values in generic script data, parameters and pending event values. Whole-valued floats stay floats; negative zero, subnormal values and finite extrema retain their exact IEEE64 bits. This prevents reload from changing Lua arithmetic or turning a rejected floating payment into an accepted integer payment. Native financial commands still require integer decicredits.

Format13 records the explicit `tagged-script-values-v1` codec marker. Every stored script value has an unambiguous type wrapper; floating payloads use16 lowercase hexadecimal bit digits. Ordinary user objects containing `type`/`value` keys remain ordinary objects. Unknown/missing fields, invalid bits and nonfinite values are rejected. This storage encoding does not change the interpreter wire or Lua API. Old formats2-12 retain their primitive-value decoder; their originally lost numeric types are not guessed. Older-format fixtures reconstruct actual primitive chunks rather than merely lowering a new pointer's version. Missing/incorrect/new-codec markers on incompatible versions cannot reinterpret a save silently.

Mission and contract chunks retain32MiB semantic limits; format13 permits up to128MiB of their more verbose tagged representation. Header/world chunks keep their4MiB/8MiB limits, and older versions retain their32MiB stored mission/contract bounds. Both semantic and stored sizes are checked before pointer publication and after reading. Earlier complete generations remain recoverable if a replacement is refused.

A structural pass checks saved JSON nesting, collection sizes, quoted escapes and string bounds before Foundation decodes large arrays/maps. A fresh decoder-local synchronized budget then enforces semantic depth32,16384 values and262144 wire-equivalent bytes per root script value, with a32MiB aggregate script-value budget per decoded chunk. Native validators continue checking the complete commander, worlds, ownership, content and resource fit before replacing live state. No oversized tree is truncated or partially accepted. The codec remains a consistency format, not a signature against deliberate save editing.

Regression tests cover all value kinds, exact floating bits, genuine queued events and terminal-parent service retry, strict payment behavior before/after reload, primitive legacy values, malformed tags/markers, excessive depth/count/bytes, escaped delimiters and near-limit valid strings, and retention of the prior pointer after a rejected replacement.

## Native commander queries

`commander-queries-v2` adds `world.commander` without changing the existing flat snapshot fields. It is an ordinary copied Lua value: editing it never changes real stock, rank, funds or fit. The selected `elite-native-player-v1` profile describes this game's actual player simulation. It does not substitute player defaults for NPC fits or import another edition's physics.

| Query | Native meaning |
| --- | --- |
| `name`, `ship_id`, `ship_name`, `kills`, `rank`, `legal_score` | Current commander, actual owned hull and native score/rank/legal state. |
| `credits_decicredits` | Integer tenths of a credit; native financial commands still require integer amounts. |
| `fuel_units`, `fuel_capacity_units`, `fuel_unit`, `jump_range_ly` | Actual fuel stock/capacity in tenths of a light year and actual native range. |
| `missiles`, `missile_capacity`, `lasers` | Actual missile stock and four native facing mounts (`front`, `left`, `right`, `rear`); absent mounts are nil, fitted mounts expose kind/name/nominal damage/minimum interval. |
| `native_maximum_speed`, `maximum_velocity_units_per_second` | Current hull's native speed and the same simulation's speed-times18 world-velocity scale. |
| `energy_capacity`, `shield_capacity`, `energy`, `front_shield`, `rear_shield`, `laser_heat`, `cabin_temperature` | Actual native limits and current physical condition. |
| `hold.capacity_tonnes`, `hold.trade_capacity_tonnes`, `hold.used_tonnes`, `hold.free_tonnes` | Current native hold/fit policy; used space includes mission payloads and fitted cabins. Assist flags are separate. |
| `hold.commodities` | Ordered17 native commodities with integer ID, name, native unit, held quantity and sellable quantity; kg/g quantities keep their units. |
| `equipment.fitted`, `equipment.stored`, `equipment.free_units` | Actual owned native equipment counts and compatible free equipment budget. |
| `accommodation` | Selected `project-common-charter-v1` profile, required operating complement, intrinsic crew quarters, source/estimate status and basis, equipment capacity, actual fitted/stored/occupied/reserved/extra-crew berths and free compatible places. The required complement is not an assertion that a living crew roster exists. |
| `assists` | Current unlimited cash/cargo/missile/fuel/jump flags; these do not bypass stricter native charter/contract fit. |
| `location` | Actual galaxy/system/name/chart coordinates/economy/government/technology and genuine current docking/main-station status. |

Unknown accommodation/fit results are nil. Native laser kills, missile consumption, hull exchange and passenger boarding update these queries through the same simulation paths used by the player.

## Completion receipts and linked missions

Every new validated `mission.finish` transition records an immutable native terminal receipt with instance/definition/version/digest/outcome, original cause sequence/kind/context, actual commit context/revision, settled milestones, genuine destroyed encounter names, delivered party names, returned equipment names and any native contract settlement amount. Cause and commit clocks are distinct when an event was delayed. Receipts publish in the same durable generation as the terminal effects. A failed publication creates neither a reward nor a receipt. Replayed facts cannot create a second completion. Old terminal flags remain readable but are never guessed into native completion proof.

Declare `completion-receipts-v2` and one or more root `[[receiptRequirements]]` tables. Each requires an exact definition (`packID/missionID`), semantic version,64-character content digest, terminal outcome (or an explicitly declared outcome set) and distinct-instance count. `stage="acceptance"` locks qualifying child IDs when accepting and rechecks them before successful completion. `stage="completion"` permits earlier acceptance but blocks a successful finish until the native children qualify. Failed/abandoned outcomes retain their own outcome-specific receipts without claiming that successful child joins happened. Maximums are32 requirements and128 children per requirement, within the shared128-instance state limit. Self dependencies, invalid fields, active-outcome requirements and undeclared capabilities are rejected before installation.

```toml
[[receiptRequirements]]
id = "patrol-report"
stage = "completion"
definition = "example.scripted-patrol/patrol"
version = "1.0.0"
digest = "f7c2123ea24e13e6d8e613a72270a052ae6b5a010e4edb678ab10a239f185906"
outcome = "complete"
minimumCount = 1
```

`world.receipt_requirements[id]` exposes `stage`, `required_count`, `matched_count`, `satisfied` and the pinned `joined_instances`. Matching uses actual native receipts, not Lua data, milestone flags, installed dependencies or similarly named actors. Native selection orders qualifying instances by receipt sequence and UUID. One child cannot count twice toward a required count. Saved joins retain their exact instance identities; inconsistent/self/future proofs are refused without replacing live state.

A declared `mission.receipted` handler receives a native notification only when an exact matching child finishes. Its values are `receipt_instance_id`, `definition`, `version`, `digest` and `outcome`, with the usual native envelope context. This notification and the child's terminal receipt belong to the same published generation. The handler queries actual requirements; merely receiving a notification does not manufacture a join or bypass a native finish gate. Queue admission reserves the whole notification batch.

Install the [linked patrol debrief](mission-packs/linked-patrol) alongside the exact [scripted patrol](mission-packs/scripted-patrol). Accept the debrief and patrol at Lave, fly the actual battle, dock and confirm the patrol report, then reopen Contacts to confirm the separate debrief. The debrief grants no additional money. Its fresh Gallery trial also requires playing the actual child mission in that isolated commander; it does not seed fake completion receipts. Use manual docking or fit the native docking computer normally. An acceptance-gated pack cannot start a fresh trial if its required receipts do not exist there. Rich historical checkpoint scenarios remain required.

Format14 retains terminal receipts and their pinned joins in the mission chunk; formats2-13 remain readable without inventing earlier proof. This implements the generic receipt/join part of linked campaigns. Shared dossiers/loans/services, full campaign source acceptance and full P19/Maenes/finance/RRS acceptance remain required before `campaigns-v1` can be advertised.

## Exclusive station choices

`exclusive-choices-v2` adds up to8 authored choices to an orbital-station dialogue. All choices in one dialogue use the same local exclusive group. A mission instance can commit one choice per group, with up to64 groups shared across its declared dialogues. Choices are ordinary declared text/IDs, with no mission-specific Swift branch.

```toml
[mission]
# Other required mission fields omitted here.
requiredChoiceGroups = ["assignment"]

[[dialogs]]
id = "assignment"
text = "Choose the work you want to undertake, then Confirm."
choices = [
  {id="patrol", label="Patrol near Lave", group="assignment"},
  {id="courier", label="Carry supplies to Zaonce", group="assignment"}
]
```

At the station, Up/Down browses choices; Left/Right selects Confirm or Back. The Previous/Next choice buttons provide the same browsing action. Return or the Confirm button commits the selected choice. Reading, browsing, Help, Back and Escape create no branch receipt or payment. Contextual help describes these controls. Reload reopens uncommitted dialogue through Contacts with a fresh selection; it does not infer that browsing meant consent.

The native `dialogue.confirmed` envelope adds `choice_id`. The authored handler must pass that exact field back in `dialogue.commit` alongside `id` and `token`. Changing the proposed choice, adding a choice to a plain dialogue, using a stale token, lacking native confirmation provenance, leaving the station or attempting a second choice in the group rejects the whole batch, including any earlier proposed credits. A failed disk publication restores the preceding state and selection for retry.

```lua
{op='dialogue.commit', id='assignment', token=event.token, choice_id=event.choice_id}
```

`world.choices[group]` is a copied native receipt containing `group`, `choice_id`, `label`, `dialogue_id`, `sequence`, original `cause` and actual `committed` contexts. Narrative flags cannot manufacture it. `mission.requiredChoiceGroups` blocks a successful finish until every listed group has a genuine receipt. An active mission can handle `dialogue.chosen` to query the committed choice in a subsequent native event; a terminal mission's frozen completion receipt contains its chosen groups directly. Choices remain immutable through later callbacks and saves.

A child's `[[receiptRequirements]]` may additionally declare both `choiceGroup` and `choice`. These fields must appear together and require `exclusive-choices-v2`. The native join still requires the parent's exact definition/version/digest/outcome and actual receipt; it then filters by the parent's frozen chosen branch. Wrong-branch follow-ups stay locked, with the branch shown in their prerequisite reason. Counts still refer to distinct qualifying parent instances.

```toml
# In the child's existing receiptRequirements table:
choiceGroup = "assignment"
choice = "courier"
```

Install the [station assignment choice](mission-packs/branch-choice), [patrol follow-up](mission-packs/branch-patrol) and [courier follow-up](mission-packs/branch-courier) together. Accept the choice at Lave, reopen Contacts, select and Confirm one assignment, then reopen Contacts to accept its separate mission. The patrol uses the actual two-ship battle/report path; the courier uses actual one-tonne custody/travel/delivery. These are original demonstrations, not historical missions. A fresh Gallery trial of the chooser uses the same station choices in its separate commander; follow-ups do not receive invented parent receipts.

Format15 saves the native choice records and the terminal receipt's frozen choices. Formats2-14 remain readable, without turning old story flags into a branch selection. This covers exclusive choices within one pinned mission instance. Shared dossiers/books/loans/services, full campaign-parent instance management and full P19/source acceptance remain required under the unavailable `campaigns-v1` capability.

## Repeatable station conversations

`dialogue-choices-v2` supports the same keyboard/click/Confirm interface for questions that may be answered repeatedly. Omit `group` from every choice in that dialogue. Each valid Confirm appends a separate native receipt; a deferred decision can be offered again. Exclusive groups continue using `exclusive-choices-v2` and retain their one-time behaviour. A single dialogue cannot mix grouped and ungrouped choices.

```toml
[[dialogs]]
id = "decision"
text = "You may defer and return later. Confirm records the selected answer."
choices = [
  {id="defer", label="Decide later"},
  {id="details", label="Ask for details"},
  {id="proceed", label="Proceed after asking for details"}
]

[[answerRequirements]]
dialogue = "decision"
choice = "details"
minimumCount = 1
```

The manifest's root `answerRequirements` tables are native successful-finish gates over this instance's actual ungrouped answers. Every declaration must reference a declared question/choice; flags or copied Lua queries cannot satisfy it. Each pair is unique, counts are positive and their combined required minimum cannot exceed1024. These gates verify actual answers; authored Lua can additionally compare native sequences and current facts for its exact narrative ordering.

`world.answers[dialogueID][choiceID]` contains compact native `count`, `first_sequence`, `last_sequence` and `label` summaries. `world.last_answer` exposes the latest native answer's `dialogue_id`, `choice_id`, `sequence`, original cause/commit contexts and `exclusive=false`. The original immutable records remain saved separately rather than copying the whole history into every interpreter call. `dialogue.chosen` for an ungrouped answer contains `group=nil` and its original `answer_sequence`; it is a result of the genuine confirmation, not another answer. Replayed or rejected confirmations cannot append a second record.

A handler may commit an answer and offer its next declared dialogue in the same batch. After the protected callback returns, a bounded second queue pass settles answer observers before presenting that next question. This does not recursively call the interpreter inside a handler. An observer that changes the conversation should explicitly reoffer its pending dialogue so its revision is current. Back, Help, browsing and previewing remain pure. A failed publication preserves the earlier answers and the uncommitted next selection for exactly one real retry.

The displayed question, token and choices are pinned when presented. If an autonomous event replaces that dialogue or changes its required revision, the view keeps the displayed question and marks the contact changed; Confirm refuses before dispatching a different question. Reopening Contacts presents the current question. Loading returns to Contacts instead of guessing that an old cursor meant consent.

The bounded adapter retains up to1024 immutable ungrouped answers per instance. A new answer at capacity is rejected as a whole, with the previous records intact; no history or counter is silently truncated. The compact query remains usable at that saved boundary. Full archival/replay remains required for unrestricted long-running histories. Format16 stores these records; older formats retain their original state without inventing prior answers.

The [repeatable conversation example](mission-packs/station-conversation) offers Defer, Details and Proceed at Lave. Defer can be confirmed repeatedly and survives reload. Asking for Details creates a genuine answer; reading its preview does not. Proceed completes only after the authored conditions and native answer requirements pass. There is no payment, loan, cargo or equipment transfer. Its isolated Gallery trial plays and saves the same real questions without altering the live commander.

## Compound child outcomes

A researched parent may require a strand to be resolved even when its source-authorized outcome is failure. With `compound-receipts-v2`, a receipt requirement can use `outcomes` instead of `outcome`. Declare exactly one form. The list contains one to three distinct terminal values from `complete`, `failed`, `abandoned`; active, unknown, duplicate or empty lists are invalid. Unlisted outcomes never qualify. All existing exact definition/version/digest/count/stage/branch checks still apply.

```toml
# In the parent's requirement for the shipment strand:
outcomes = ["complete", "failed"]
```

Every declared requirement must still join its own genuine child instance. A four-child native test flies four actual patrol cohorts, reports three as successful and one as failed without its success payment, then joins all four exact receipts. It also verifies that a success-only requirement rejects that failed child and that the pinned joins survive reload. This proves the generic compound mechanism; full historical P19 strands, rich book assets, shared loans/services and whole-campaign acceptance still require their remaining native systems and source content.

## Retained reference books

With `library-books-basic-v2`, a pack can declare up to32 text books in root `[[books]]` tables. Each book has a unique local `id`, a `title` of1-96 characters and1-64 ordered `chapters`. Each chapter has unique local `id`, `title`, `text` and hierarchy `level`0-4. Text must be valid UTF-8 with1-12000 bytes per chapter and at most131072 bytes per book; the existing whole-manifest bound still applies. Example:

```toml
[[books]]
id = "field-notes"
title = "Station field notes"
chapters = [
  {id="welcome", title="Welcome", level=0, text="Reference information for future station visits."},
  {id="cargo", title="Preparing cargo", level=1, text="Check the actual free hold before accepting freight."}
]
```

An active handler returns `{op="book.unlock", id="field-notes"}` to grant its own declared book as part of its normal atomic transaction. Native ownership retains exact provider/version/digest, copied text, source/licence, content hash, original instance/sequence/cause and committed revision/clock context. `book.unlocked` is a derived event for the still-active origin. A terminal mission does not regain execution rights. Repeat grants preserve the original record and reading position; different content requires an explicit migration. The global limit is64 owned books; a new grant at capacity is rejected as a whole. Books survive completion, failure, abandonment, hull changes, reload and removal of their original installed pack.

The optional `[mission] requiredBooks=["field-notes"]` list is a native successful-finish gate over this provider's exact granted edition. A narrative flag or fabricated Lua value cannot satisfy it. `world.library` exposes compact ordered headers (`key`, `title`, `provider`, `version`, `digest`, chapter count), without copying full text into every callback.

**Game > Mission Library** opens the native book list. Return/click opens contents and chapters; arrows/Page Up/Page Down scroll, Tab returns to contents, I opens source/licence, and Escape backs out to the preceding screen. Contextual K help explains the current page. The saved reading position restores on load. Long titles and source identifiers wrap within the pane. Reading is presentation-only: it does not invoke Lua/contact callbacks, change mission decisions or transfer money/property. Flight, combat and mission-local/calendar time freeze while reading; independently resource-owned loaded-world jobs retain their documented behavior. Source/hash validation occurs on native construction and decoding, not repeatedly during rendering.

Format17 retains the book ledger and reading cursor. Older formats invent no book ownership. The [original reference-book demonstration](mission-packs/reference-book) grants its notes through a real station briefing, completes with no credit reward and remains readable afterward, including in its isolated Gallery trial. Native menu/click/paging/ordered-Save tests verify that reading does not alter commander mission state. This basic capability covers text and hierarchy; source images/logos, rich dossiers, shared financial services and full historical acceptance remain outstanding.

## Partial native material collections

With `partial-collections-v2` and `story-v2`, a pack declares up to32 root `[[collections]]` definitions. Each has a unique local `id`, `title` of1-96 characters, zero-based `galaxy`0-7 and `system`0-255 for its actual main orbital station, and1-17 `items`. Every item uses its unique native `commodity` index0-16, exact native `unit` (`t`, `kg` or `g`) and integer `quantity`1-1000000. An incorrect unit, repeated commodity, unknown field or fractional/negative quantity is invalid. Example:

```toml
[[collections]]
id = "materials"
title = "Workshop materials"
galaxy = 0
system = 7
items = [
  {commodity=2, unit="t", quantity=10},
  {commodity=14, unit="kg", quantity=1}
]

[[dialogs]]
id = "handoff"
text = "Review the actual quantities before confirming."
collection = "materials"
```

An active handler returns `{op="collection.ensure", id="materials"}` once the source authorizes that request. The native per-instance ledger freezes the declared terms; repeated ensures do not reset delivered quantities. Initializing a request grants no goods. A dialogue with `collection` uses no answer-choice list. Its ordinary `dialogue.offer` freezes the current native requested/delivered/outstanding/aboard/unreserved/transfer quantities at that assigned main station. The handoff screen renders these actual quantities and units after its authored paragraphs. Reading, Help and Back make no transfer. Changing the relevant cargo makes the displayed quote stale before the interpreter runs; reopen Contacts to obtain a fresh quote. A quote with no positive available outstanding goods stays readable and refuses Confirm without suspending the mission.

The confirmed handler uses `{op="collection.deliver", id="materials", token=event.token}`. This command performs the genuine current `dialogue.commit` checks itself; do not precede it with another `dialogue.commit`. It consumes `min(actual unreserved aboard units, outstanding units)` per requested commodity. At least one quantity must be positive. Excess, unrelated native goods, the marked Blackjack firearm, separate mission payloads, passengers and gear remain intact. Only the actual assigned main orbital station qualifies. A new genuine confirmation can transfer another partial lot using the same collection ID; the native event sequence identifies that lot. Replaying the earlier event/token cannot take another consignment.

Each immutable lot records actual native units, original instance/sequence/dialogue and original/committed native clock/location/revision context. Its gram total uses1000000 per tonne,1000 per kilogram and1 per gram. Cumulative deliveries and outstanding quantities derive from these records; Lua narrative flags cannot replace them. `world.collections[id]` exposes title, station, actual complete state, ordered requested/delivered/outstanding items and a current ordered native `quote` at the valid station (otherwise nil). Quote rows additionally include commodity name, aboard, available and transfer `quantity`. The derived `collection.delivered` event carries `collection_id`, `lot_sequence`, actual `mass_grams` and native `complete`, only while the origin remains active.

`[mission] requiredCollections=["materials"]` is a native successful-finish gate over complete exact declared collections. A failed/abandoned mission keeps delivered lots without manufacturing a successful handoff or refund. Lots survive hull changes, saves and later visits. Up to1024 partial lot receipts total are admitted per instance; an additional lot is rejected as a whole and no prior history is truncated. Every batch and its output facts use the existing durable barrier: later command failure rolls back staged goods/lot changes, and filesystem failure preserves the original offer/cargo/earlier receipts for a real retry. Format18 persists collections/quotes; old saves invent no deliveries. Invalid units, quantities, owner identities and quote/ledger disagreement are refused on load even if the outer chunk hash is updated. Quantity validation precedes cumulative arithmetic.

The [original material-collection example](mission-packs/material-collection) requests19t plus1kg through repeated actual orbital handoffs, with no reward or gifted stock. Its Gallery trial starts with cash for normal native trade. These ledger units do not change the existing BBC trade hold's quantization of kilogram/gram goods or implement full typed world cargo/pod custody. A future shared unit-aware payload adapter must preserve the same unreserved-quantity and ownership boundary. Historical finance still needs its sample/pylon/thermal/scoop/receiver, moving contact/docking, shared loan and full-source acceptance; this demonstration does not enable that campaign.

## Native inputs belong to the displayed page

Native keyboard and handoff mouse input carries the page identity captured when the view last painted it: its save/trial context and either the available script pack digest, active question instance/token/revision, or schema1 handoff identity. An input from a frame with no offer/question also carries that absence. The runtime compares the captured identity before calling its existing transactional input handler. An older frame cannot accept a newly opened offer, answer a replacement question, or confirm after a commander/trial context changes.

The native view retains the painted identity separately from the next model snapshot. Two queued Returns or clicks from the same old page cannot answer a chained next question, including an additional input after command processing but before repaint. Once the new page is drawn, a new confirmation can answer it normally. Selection is deliberately separate: arrows followed by Return on the same displayed question still choose the intended answer. Reading, scrolling, Help and Back do not manufacture answers. Malformed/oversized input envelopes and invalid identities are refused without executing business handlers. Existing trusted direct `GameRuntime.key` callers keep their original behavior; this guard protects the native window's real input/queue boundary.

This is presentation context, not persistent script state, and does not change save format18 or create a new content capability. Native event tests reproduce the original double-confirm issue before the fix, then verify single-answer behavior, initial offer/question protection, keyboard/mouse parity, same-page selection and reload rejection through the actual AppKit queue and actor pipeline. No new visible controls or mandatory confirmation screen are added.

## Owned campaign children

Declare `scoped-campaigns-basic-v2` and root `[[children]]` tables, each with a unique local `id`, exact `definition`, `version`, `digest` and explicit `terminalPolicy="suspend"` or `"preserve"`. These declarations authorize child templates; they do not claim that a child has started or completed. Up to32 children per parent and four relationship levels fit inside the existing128 total saved-instance limit. A board job can own children, but a child template itself cannot be a board provider.

```toml
[[children]]
id = "patrol"
definition = "example.scripted-patrol/patrol"
version = "1.0.0"
digest = "f7c2123ea24e13e6d8e613a72270a052ae6b5a010e4edb678ab10a239f185906"
terminalPolicy = "suspend"

[[receiptRequirements]]
id = "owned-report"
child = "patrol"
stage = "completion"
definition = "example.scripted-patrol/patrol"
version = "1.0.0"
digest = "f7c2123ea24e13e6d8e613a72270a052ae6b5a010e4edb678ab10a239f185906"
outcome = "complete"
minimumCount = 1
```

Lua proposes `{op='child.ensure',id='patrol'}`. Native code validates the active owning parent, declaration, exact installed child content, dependencies/capabilities, relationship depth and whole-instance/event capacity. A deterministic child UUID and independent script seed derive from the parent UUID, alias and exact content without drawing simulation randomness. Different parents or aliases receive distinct instances even when they use the same template. Repeating an ensure retains the same original child, including its terminal result, faults, actors, spent stock and pending events; it never resets, heals or reissues it.

The parent and child retain the same immutable binding, root/depth and original cause/commit provenance. Their relationship and the child's native accepted event publish in the parent's complete transaction. Child Lua runs later from that accepted event, after the parent proposal has committed. A later invalid parent command or failed filesystem publication leaves no child, binding or accepted event behind. A subsequent child initialization fault retains the original identity and pending cause for explicit retry.

`world.children[alias]` is a compact read-only native snapshot containing `instance`, `root`, exact content identity, `outcome`, `suspension` and `receipted`. A newly created binding emits `campaign.child.started` to its parent, with `child` (alias) and `instance`. A receipt requirement with `child` can use only `stage="completion"` and `minimumCount=1`, with the exact declared child's content. Its query, notification, pinned join and successful-finish check admit only that parent's actual bound child. An earlier standalone receipt or another campaign's child cannot qualify. Requirements without `child` keep their existing global prerequisite behavior.

A child template may declare `[mission] parentOnly=true` with this capability. It is then absent from standalone station offers and cannot start a standalone Gallery trial or direct acceptance. Its owning campaign starts it. Existing templates without this restriction may also be used as independent missions; their independent completions still cannot satisfy a scoped requirement.

When a parent becomes terminal, each `suspend` edge blocks business execution below it, including grandchildren whose immediate edge says `preserve`. Actual child people/property, encounter identities, damage, stock and safe native world state remain intact. Retry cannot revoke that terminal-parent gate. `preserve` explicitly allows the child to continue when its owning ancestors permit it. Independently resource-owned maintenance jobs retain their existing rights and lifetime; this capability does not grant terminal missions renewed reward, credit or custody rights. Missing exact owning content suspends the intact relationship until restoration and explicit retry.

Format19 retains both relationship ends and scoped requirement aliases. Inconsistent inverse/root/depth/provenance/joins refuse load even with a recalculated outer chunk hash; bounded validation precedes relationship arithmetic. Formats2-18 remain readable without inventing children, and an older format cannot conceal new relationship fields. The Gallery keeps each owned child as a separate saved entry, displays its owning campaign and the parent's assignment statuses, and starts trials from the campaign rather than an owned child row. Browsing remains read-only.

Install the [owned patrol campaign](mission-packs/scoped-patrol) with the exact [scripted patrol](mission-packs/scripted-patrol). Acceptance starts its child automatically. Fly the actual patrol, confirm its own station report, then confirm the campaign debrief. The isolated Gallery trial follows the same physical steps and has separate saves. This original example is not P19 acceptance. Shared financial services/dossiers/loans, full historical AI/transit/custody and full historical campaign trials remain required before `campaigns-v1` is advertised.
