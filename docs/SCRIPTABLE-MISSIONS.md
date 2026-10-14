# Scriptable mission packs

The script engine is being implemented on `feature/scriptable-mission-engine`. The implemented verticals run authored Lua story, station, courier, humanoid passenger, timer and native classic encounter logic without a mission-specific Swift class. It preserves schema 1 and the three bundled campaigns. This is not completion of the full physical mission-engine design, and none of the queued historical research campaigns is enabled by this example.

## Install and play the example

Choose **Commander > Install Mission Pack**, then select the [scripted courier folder](mission-packs/scripted-courier). At a main orbital station, open **Mission Contacts**, read the offer and confirm. Acceptance requires one free tonne; Back does nothing. Carry the sealed supplies to Zaonce in Galaxy 1, visit its main orbital station, and confirm delivery for 50 credits. The authored Lua module controls the branches; native code validates location, owned cargo, capacity and the balance. This original demonstration is separate from the historical mission catalogue.

The Gallery shows installed scripted missions and preserves missing-pack references, status, milestones and rendered journal entries. Browsing remains read-only. Select a supported schema 2 pack and press **T**, or choose **Game > Try Selected Mission**, to enter an isolated, seeded trial with a fresh commander and its own save directory. **Game > Restart Mission Trial** resets that scene; **Game > Return to Commander** restores the complete live game and its save destination. A failed trial restarts with Space/Return. Save, Save As, Load and Open operate within the trial namespace and preserve the live file and recent-file preferences. Window titles label trials. Unsupported and legacy entries have no trial action. Full authored historical world scenarios remain to be implemented.

## Format and interpreter contract

A schema 2 folder contains `manifest.toml` and its declared pack-local UTF-8 Lua module. See the [example manifest](mission-packs/scripted-courier/manifest.toml) and [module](mission-packs/scripted-courier/scripts/main.lua). The manifest declares API 2, minimum engine contract 2.0.0, identity/version, dependencies, source/license, space/orbital environments, handlers, dialogue and milestones. Unknown fields, invalid paths, linked resource components, oversized files, unsupported environments and syntax/module-initialization errors are rejected. Every declared handler must exist.

Installation snapshots and verifies the bytes, then publishes a new folder named from pack ID, version and content digest under `~/.xyzzy/elite/mission-packs/scripted`. Identical content is idempotent. Existing version folders are retained. Saved instances require their exact digest and dependency set; missing content suspends progress while retaining the cargo and event queue. Restore the original pack and select its suspended Gallery entry and press **R**, or choose **Game > Retry Selected Mission**; a changed pack is not an implicit migration.

Each named function receives `(event, world, data)` and returns `{data = a_map, commands = an_array}`. `world` is a scoped value snapshot: galaxy/system, genuine docking/main station, decicredits, free tonnes native clock values and the actual durable-commands mode. `event.kind`, `sequence` and event-specific values come from the engine. Editing either table cannot mutate native facts. Persistent data must be explicit finite values; functions, userdata, cycles, sparse/mixed-key tables, invalid UTF-8 and excessive nesting are rejected. Empty Lua tables decode as empty maps and are accepted as empty command arrays. Module globals and closures are recreated on every dispatch.

The interpreter exposes base scalar/assert/error/type/iteration helpers and numeric math, without `pairs`/`next`, metatables, catch/resume, loaders, packages, I/O, OS, debug, string/table libraries or independent random/time. Use numeric loops and `ipairs` over ordered arrays. `tostring` accepts scalars only. VM entry, allocation, hooks, library setup, serialization and error unwinding are entirely C; no Lua error unwinds across a Swift callback. There are no interpreter pointers in game snapshots.

## Implemented native capabilities

| Capability | Current executable support |
| --- | --- |
| `script-lua-v1` | Bounded programmable handlers, fresh environment, validated explicit data and proposals. |
| `story-v2` | Native scoped station dialogue/confirmation, journal, story milestones and terminal outcomes. |
| `economy-v2` | Signed integer decicredit debits/rewards with checked balance and per-instance operation receipts. |
| `cargo-v2` | Owned mission payload lots counted against the current hold, atomic issue/removal and receipts. |
| `local-flight-clocks-v2` | Saved local/flight clocks, one-shot/fixed-delay/skipped-interval named timers and actual fired pulses. |
| `classic-encounters-v2` | Full-cohort admission for declared classic NPCs, persistent world identities and actual destruction/removal facts. |
| `charter-passengers-v2` | Actual common humanoid cabin fit, owned passengers and orbital-station delivery receipts. |
| `owned-equipment-v2` | Unique native gear, hull transfer/surplus storage/refit, scoped quest issue/return/release, true consumption and return gates. |
| `gallery-basic-v2` | Isolated player-facing trials, validated starting loadout, native launches, restart/return and separate saves. |
| `durable-commands-v2` | Bound-writer publication before command effects, atomic failure/retry and post-physics script transactions. |

Required capabilities outside this set keep a valid pack unavailable. In particular `world-clocks-v1` from the design is not advertised: all four source domains and independently owned world jobs are not implemented yet. No physical kill objective can be proved by a story milestone, contact, role name or installed pack.

Current events are `mission.accepted`, `station.docked`, `station.undocked`, `system.entered`, `contact.requested`, `dialogue.confirmed`, `timer.fired` and reserved `mission.abandoned`. Classic encounter packs additionally receive `encounter.admitted`, `encounter.pending`, `actor.destroyed` and `actor.removed`. Dock/location events are observed after native simulation/input changes. No public script API manufactures physical destruction, wormhole, passenger or equipment events.

| Command | Fields after `op` | Native checks |
| --- | --- | --- |
| `credits` | `id`, signed integer `amount` | Declared economy capability, once-only operation, balance 0-4294967295 decicredits. |
| `payload.add` / `payload.remove` | `id`, `key`, positive integer `amount` | Declared cargo capability, owned lot, final whole-batch hold fit, once-only operation. |
| `milestone.ensure` | zero-based `index` | Declared story milestone; idempotent. These are story milestones, not physical-objective receipts. |
| `journal.append` | `text` | Bounded rendered text and journal count. |
| `dialogue.offer` | declared dialogue `id` | Actual main orbital station; pins instance, location and revision token. |
| `dialogue.commit` | `id`, native event `token` | Actual matching confirmation, current location/revision and offer. Back cannot issue this event. |
| `timer.ensure` | `id`, `domain`, `after`, `interval`, `policy` | Local/flight domain, finite bounds, `once`/`delay`/`skip`, saved native due/pulse state. |
| `timer.cancel` | `id` | Removes this instance's timer only. |
| `encounter.ensure` | declared encounter `id` | Saved identity plan, exact location/profile, whole-cohort capacity and clear placements before admission. |
| `passengers.board` / `passengers.deliver` | `id`, declared `party` | Actual station/location, fitted compatible cabin, stable person ownership and once-only transfer. |
| `mission.finish` | `outcome` | `complete` requires every milestone, required passenger delivery and declared required destruction encounter; `failed`/`abandoned` are terminal. Place this last. |

Commands and explicit data form one staged commander transaction. The desktop runtime writes it durably before publishing effects; a memory-only embedding must opt into a save destination, and packs can require `durable-commands-v2`. See [transaction guarantees and recovery](DURABLE-MISSION-TRANSACTIONS.md). An invalid command, unknown field, denied balance/hold, stale confirmation or execution fault discards the proposal. Already accepted instances suspend with their original data/property and unacknowledged event; initial acceptance fails without creating an instance. Subsequent events cannot revive or repay a terminal instance. A source-authorized failed payment can precede the terminal command in the same batch. Personal equipment storage and passenger custody are not payload substitutes. See [common charter accommodation](PASSENGER-ACCOMMODATION.md) for fitting, storage controls, source limits and the passenger example.

Local time continues in loaded unpaused docked panels and handoffs, freezes in Help/Gallery/route planning/explicit pause, and advances by the native capped tick. Flight time follows actual native flight simulation, including charts that leave flight running. Inactive domains cannot fire already-due timers; opening the Gallery does not process them. A skipped timer fires once after a late tick and schedules the next original interval; it does not replay missed pulses. Calendar/transit progression and independent world-job ownership remain unavailable. Clocks do not create empty script state in legacy commanders.

## Actual classic encounters

The [scripted patrol](mission-packs/scripted-patrol) is a second original demonstration: accept at a station, launch at Lave, fight the two actual assigned raiders, dock through the native flight controls and confirm your report. The acceptance test uses real lasers and automatic docking. Ordinary kill/bounty/Right on Commander behavior remains in native combat; an allied/environmental kill can satisfy the owned destruction objective without granting a player bounty.

Declare `[[encounters]]` with `id`, `galaxy`, `system`, `profile` and an `actors` array. Each actor declares an exact alias, native `hull`, station-relative `x/y/z` and `hostile`. The supported profile is **classic-local-freeze-v1**: existing native Cobra/Viper/Sidewinder/Constrictor/Thargoid/Thargon NPC behavior and fitting, with unloaded/docked scenes frozen. This is not an Oolite physics or AI adapter. No source NPC zeros are replaced with player starter equipment.

The manifest mission's optional `requiredDestructionEncounters` lists cohorts that must actually be admitted and entirely destroyed before successful completion. Lua reads scoped `world.encounters` facts; copying an event, matching a role or declaring a milestone cannot create a native tombstone. The `encounter.ensure` result arrives later as a native event. Obstructed/over-capacity deployment retains its prepared identities and returns pending; no partial fleet appears. Subsequent commands in the same transaction can still roll back the entire staged admission.

Actors keep a stable world UUID separate from reusable scene integer IDs. Main-station-relative canonical position, orientation, energy and spent stock persist through genuine docking/launch/system transitions and saves. The main station reference follows the same actual player frame even when its visible mesh is culled, including in-system jumps. Returning actors reproject from their stored world position; they are not healed, restocked or moved into range. Leaving the loaded region records removal rather than destruction. Same-frame fatal hits settle before scene unload and ordinary bounties remain once-only.

The native capacity test admits 82 actual classic roots. It is a generic capacity/identity fixture, **not Maenes acceptance**: the latter still requires its actual custom fits, components/turrets, crew/custody, AI/transit, all clock domains, station jobs and source-law adapters. Keep full historical packs gated on those capabilities.

## Saves and bounds

Normal commanders without scripted instances, owned equipment or owned cabins retain the existing single JSON format. Scripted commanders publish a small JSON generation pointer plus a sibling `.missions` directory. Each immutable generation contains hashed `commander.json`, `missions.json` and `world.json`. All new chunks are written before the pointer is atomically replaced; earlier generations remain recoverable. Load validates every chunk and the complete candidate before replacing actor state. No ordinary docking, reward, auto-trade or Lua constructor callbacks replay during scripted restore. The reader retains formats 2 through 6; writers publish format 7 with an explicit commander/gallery scope tag, which older readers reject rather than silently discarding actor or passenger data. Preserve both the pointer and its sidecar when copying a scripted save.

The current format-7 world chunk preserves native RNG/tactics/spawn/weapon/ECM counters, temperature/altitude, exact solar bodies/kinds/radii, fractional scoop fuel and scoop-controller state, an offscreen station reference, stable owned encounter records, local bodies/market, location/docking/view, energy/shields/heat, speed/time, selected system, jump countdown and next body ID. Full source-profile AI/controller/transit/care/campaign world persistence remains part of subsequent physical implementation; this first chunk must not be used as proof that all researched battle state can be restored. Publication currently runs synchronously inside GameRuntime, which prevents actor reentrancy during the write. Automatic Confirm and post-physics script publication use that synchronous barrier. Background writer scheduling, bounded input backpressure and explicit migrations remain required by the full design.

Initial quotas are 50000 VM instructions (1000-instruction hooks), 8 MiB heap, 32 MiB allocation work, 512 KiB proposal output, 256 KiB explicit data, 256 commands, depth 32 and 16384 exchanged values. Collections, journals, receipts, instances and pending events have native limits. These are bounded initial implementation limits, not permission to truncate researched encounter counts. VM faults cannot publish partial output.

The [24-requirement status map](SCRIPTABLE-MISSION-STATUS.json) records partial and unsupported groups separately.

## Validation and remaining implementation

The [validated checkpoint](SCRIPTABLE-MISSION-VALIDATION.json) passes 377 tests in each coverage/thread/address lane, 93.54% maintained coverage and zero native diagnostic leaks.

Run `make script-missions-check` for the three authored examples, `make test` for behavior and `make ci` for repository gates. Tests cover script execution, quota faults, invalid output, initial acceptance rollback, whole-batch cargo/economy rollback, stale/Back/valid Confirm, terminal reward replay, missing content/cargo preservation, local timer skips, isolated trials, old saves, immutable generations and corrupt/failed saves. The maintained C shim is included in coverage; only unmodified third-party Lua is excluded from the maintained-code percentage and Sonar source scope. Compiled Lua still runs under sanitizers and leak checks.

The full design additionally requires actual owned fleets/components and admission, native AI/docking/wormholes/weapons/death objectives, all source clock domains and persistent station jobs, people/life support/crew/berths, full source-specific gear condition/modification adapters, contract boards/quotes/repeatable jobs, compound campaign receipts, complete physical save/migration/replay services, deterministic plans, full Gallery scenes/tools and native Maenes/finance/RRS acceptance. These remain unsupported, with no historical mission rewritten into a courier to bypass them.

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
