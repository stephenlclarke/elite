# Schema 2 Lua mission authoring

Schema 2 packs are folders containing a TOML manifest and pack-local Lua source. They coexist with [legacy schema 1 single-file missions](MISSION-PACKS.md). This guide describes the current loader and native mission API; a declaration or a research specification does not establish an implemented historical scenario.

## Start from a complete example

Copy the whole [scripted courier folder](mission-packs/scripted-courier), including its [manifest](mission-packs/scripted-courier/manifest.toml) and [Lua handlers](mission-packs/scripted-courier/scripts/main.lua). It accepts one protected payload, offers delivery at the actual destination main station, and commits transfer and payment on Confirm. Give your own pack and mission new stable IDs and appropriate source/license declarations.

```text
my-pack/
  manifest.toml
  scripts/
    main.lua
```

The manifest header uses these exact compatibility values; the current loader does not interpret `minimumEngine` as an open-ended version range:

```toml
schemaVersion = 2
missionAPI = 2
id = "example.my-mission"
version = "1.0.0"
minimumEngine = "2.0.0"
capabilities = ["script-lua-v1", "story-v2", "economy-v2", "cargo-v2"]
```

This header is an excerpt. Retain the example's required `priority`, `source`, `license`, `environments`, `module`, `[mission]` and `[[handlers]]` declarations. Pack and mission IDs match `[a-z][a-z0-9.-]{0,79}`; versions have three numeric components. Local action IDs allow an initial uppercase letter too. `priority` is 0-1000, environments are `space` and/or `orbital-station`, and the main `module` is a relative `.lua` path. Unknown manifest keys are rejected.

The persistence definition is `pack.id/mission.id`. Each accepted assignment also has its own instance UUID. Pack version and content digest identify its exact code and declarations; changing a byte can change the content identity even if the version stays the same.

## Install and inspect

Choose **Commander > Install Mission Pack...** and select the complete folder, with `manifest.toml` at its root. The same picker accepts legacy TOML files. The schema 2 installer retains immutable content versions in `~/.xyzzy/l337/script-packs/`, separate from the legacy file library. Manual copying of a complete folder into that directory is also supported after restarting; keep each content version separate. Up to 128 external library entries can be loaded. The app also loads the bundled [generated courier provider](../Sources/L337Core/Resources/ScriptPacks/generated-couriers/manifest.toml); the other example folders linked here are authoring examples, not automatically installed packs.

Validate either a legacy file or a schema 2 folder with the same command:

```sh
swift run L337 --validate-mission-pack path/to/pack-folder
```

Folder validation reuses the protected reader: it checks the manifest, declared modules/assets and Lua handler exports, then reports the version and content digest. It does not install anything or establish runtime availability. Unsupported capabilities are reported, and dependency requirements are listed as declared `id@version` pairs rather than claimed installed. A well-formed unavailable pack can still be installed as a Gallery reference; existing dependency, capability, commander-save and acceptance gates remain authoritative. Selecting `manifest.toml` itself does not substitute for selecting its folder. `make mission-packs-check` continues to check the legacy example.

Choose a commander save before running a pack that declares `durable-commands-v2`. Read its Gallery availability and objectives, then use Mission Contacts or Station Contracts as appropriate. Install content in the main game before starting a trial. A pack with `gallery-basic-v2` and a valid `[trial]` can declare a test ship, location, credits, cabins and whether it starts in flight; board trials may select a declared offer. Trials use separate state and save storage. Restart repeats the trial setup; Return restores the live session.

## Handler contract and native authority

The Lua module returns a table of named functions. Each manifest `[[handlers]]` maps one supported event to an exported function; each event appears at most once. A function receives `(event, world, data)` and returns exactly `{data = a map, commands = an array}`. The courier example demonstrates the complete pattern.

`world` is a native snapshot of the current location, station, commander resources, clocks and this instance's owned encounters, passengers, issued gear, answers, children and contract. Use the supplied fields instead of inventing global state or station identities. Galaxy and ordinary system numbers are zero-based. Money commands and contract rewards/deposits use tenths of a credit: `500` means 50 CR. Milestone indices start at zero.

Lua proposes changes. Native code checks command fields, declared capabilities, ownership, current location, physical fit, receipts and state limits before publishing a whole proposal. Invalid commands or a failed required save do not publish part of that proposal. Physical hits and deaths that already happened remain real; a script failure does not rewind combat. Faulted work is suspended with an explanation rather than silently retried as a new assignment.

Use stable action `id` values for once-only operations such as `credits`, `payload.add` and `payload.remove`; their receipts belong to the instance. Use `milestone.ensure` for objectives, and `mission.finish` only after the actual required native objectives qualify. Setting a narrative field such as `data.phase = "complete"` does not create a completion receipt or destroy an actor.

Contact handlers use `dialogue.offer` for a declared station dialogue. On `dialogue.confirmed`, recheck the current world and include `dialogue.commit` with the actual `event.dialogue_id` and `event.token` before the transfer commands, as in the courier example. Native validation rejects stale tokens, revisions and locations. Back and preview navigation do not confirm a handoff.

## Capabilities and working references

Declare only the capabilities needed by the corresponding native operations. `script-lua-v1` is mandatory. The [implemented capability set and manifest validation](../Sources/L337Core/ScriptPack.swift) are authoritative; command-specific checks also apply.

| Feature | Capability or capabilities | Complete reference |
| --- | --- | --- |
| Story, station dialogue and milestones | `story-v2` | [Scripted courier](mission-packs/scripted-courier/manifest.toml) |
| Cash and protected tonne payloads | `economy-v2`, `cargo-v2` | [Scripted courier](mission-packs/scripted-courier/scripts/main.lua) |
| Repeatable station offers | `contracts-basic-v2`, `local-flight-clocks-v2`; `durable-commands-v2` for this example | [Sample contracts](mission-packs/scripted-contracts/manifest.toml) |
| Commander calendar offers | Above, plus `calendar-clocks-v2` | [Calendar contracts](mission-packs/calendar-contracts/manifest.toml) |
| Native generated courier custody | `courier-contracts-basic-v2`, `mission-calendar-v2` and the bundled declarations | [Bundled courier](../Sources/L337Core/Resources/ScriptPacks/generated-couriers/manifest.toml) |
| Declared classic or profiled actors | `classic-encounters-v2` or `profiled-encounters-v2` | [Patrol](mission-packs/scripted-patrol/manifest.toml), [profiled skirmish](mission-packs/profiled-skirmish/manifest.toml) |
| Passenger parties and equipment custody | `charter-passengers-v2`, `owned-equipment-v2` respectively | [Passengers](mission-packs/scripted-passengers/manifest.toml), [equipment](mission-packs/scripted-equipment/manifest.toml) |
| Exclusive branches or repeatable answers | `exclusive-choices-v2` or `dialogue-choices-v2` | [Branch choice](mission-packs/branch-choice/manifest.toml), [conversation](mission-packs/station-conversation/manifest.toml) |
| Verified follow-up or owned children | `completion-receipts-v2`, `scoped-campaigns-basic-v2` for owned children | [Linked patrol](mission-packs/linked-patrol/manifest.toml), [scoped patrol](mission-packs/scoped-patrol/manifest.toml) |
| Books and partial material handoffs | `library-books-basic-v2`, `partial-collections-v2` respectively | [Book](mission-packs/reference-book/manifest.toml), [collection](mission-packs/material-collection/manifest.toml) |
| Declared modules and scheduled world jobs | `pack-modules-v2`, `world-resource-jobs-v2` respectively, with their required supporting capabilities | [Profiled module](mission-packs/profiled-skirmish/manifest.toml), [station maintenance](mission-packs/station-maintenance/manifest.toml) |
| Native station donations | `station-pledges-basic-v2` and the declared donation profile | [Station donation](mission-packs/station-donation/manifest.toml) |

The [original fixed-principal finance product](mission-packs/finance-obligation/README.md) declares `[[loans]]` with `finance-obligations-basic-v2`, `story-v2` and `durable-commands-v2`. `finance.offer` registers its exact declared contact offer; it grants no credits. Station Contracts presents native Finance rows for explicit Borrow/Decline or Repay confirmation at the proved original main station. Repay takes the lesser of real balance and outstanding debt, carrying any remainder. Accepted liabilities and receipts survive terminal or missing parent content; pending offers require the exact active parent. The existing authenticated current native save path retains financial terms and receipt facts. These generic profiles do not implement historical GSE short/zero-balance closure, default scheduling, escrow or complete P04/P19 content. New source and authored regressions still require integrator compilation, runtime and full quality acceptance.

The [original interest example](mission-packs/finance-interest/README.md) adds `finance-interest-simple-v2`, `mission-calendar-v2`, `profile = "simple-interest-v1"` and a `[loans.interest]` table with mandatory `rateBasisPoints`, `periodSeconds`, `rounding` (`up`/`down`) and `maximumInterest` (lifetime cap in native tenths of CR). Interest is simple, rounded per completed borrow-anchored period on outstanding principal; partial payments pay interest first and never restart periods. The cap includes all interest ever assessed, not only unpaid interest. UI/Lua projections are pure; explicit Confirm records elapsed assessment atomically with payment and rejects changed projected balances. Lua `w.finance.<loan>` exposes `remaining`, `remaining_principal`, `accrued_interest`, `assessed_interest`, `completed_periods`, `calendar_seconds`, `interest_profile`, `rate_basis_points`, `period_seconds`, `rounding` and `maximum_interest`. No interest accrues before Borrow or after payoff/Decline, and native calendar events rather than wall-clock/offline time determine elapsed periods. Missing fields in the new required current receipt model are rejected; no predecessor migration is supplied.

Classic actors and profiled actors use native admission, movement, collision, weapon and law rules. `hostile = true` is not an exemption from station weapon restrictions. Destruction objectives require the actual admitted owned actors to be destroyed. Declare supported actor/model/weapon resources; Lua does not directly write world bodies or add arbitrary station services. Generic contract boards currently identify main orbital stations. The examples and capability names do not establish delivery of a researched RRS station world or historical mission parity.

### Native NPC wormhole transit

The authored native provider uses `npc-wormhole-transit-v2` with `profiled-encounters-v2`, `story-v2`, `durable-commands-v2` and `mission-calendar-v2`. An NPC profile declares `[npcs.drive]` with a real `component` alias, `rangeLightYears`, `activationSeconds`, `massLockScale` and `fuelUnit = "native-light-years"`. The alias must exist in that fit and resolve to its actual surviving component; absent/damaged drive, native EMP/electrical depletion, insufficient fuel and actor-relative mass lock refuse. The explicitly typed fuel is the NPC's own profiled reservoir, not commander fuel or a second ordinary-NPC tank.

`{op="actor.transit", id="leg", encounter="escort", actor="lead", destination="G01-S007"}` requests one stable leg. Destination is an exact installed original-world key, never a name or selected-system alias. The example key illustrates syntax and grants no route or campaign authority. The native resolver authenticates both records against G1's single catalogue and uses its actual Cartesian light-year policy. Unknown worlds, mismatched records and ordinary-world requests from PLUGH remain refused; a separate genuine secret-world policy is required. This source depends on G1's live production-world leaf and endpoint validation, with manual travel-hook composition and central qualification still pending.

Spooling, opening and intent are not departure. A live, bounded, visible spatial aperture must receive the actual native swept hull crossing before one fuel debit and source detachment can publish. The same retained logical actor and spent resources remain in transit until the quoted due time, then pending until actual destination native admission succeeds. Missing/unloaded/blocked scenes grant no arrived event. `actor.transit.opened`, `actor.transit.departed` and `actor.transit.arrived` describe different native results; none is station reception, escort settlement, destruction, clue or payment. Those require their separate actual receipts. No arrival or resource reset is synthesized on load. Unsupported recovered EMP/pod/salvage custody refuses rather than losing its identity.

Read-only `w.transit` is keyed by leg UUID and reports actor/request, phase, destination, refusal, due time and actual departure/arrival times. In-transit actor positions are null; there is no moving invisible GPS target. `actor.transit.retry` uses the same fields and exact leg identity to refresh a finite retry budget, without another hole, debit or ship. Current saves retain native route/owner/condition/expiry/pending/history facts, which still require fresh native authority before use. Global `transit_seconds` advances once for actual commander native travel; two concurrent NPC journeys do not add travel time. With `local-flight-clocks-v2`, this transit capability also authorizes `timer.ensure` with `domain="transit"`; only actual commander transit dispatches it. No historical campaign or native runtime acceptance is claimed by these authored interfaces. See the [scope, dependency and acceptance plan](PR-native-npc-wormhole-transit.md).

### Native RRS adapter and authority

The current development source separately composes native RRS docking and the built-in P30 scenario-2 documents assignment. This is a typed native consumer, not a Lua pack to install or a new capability granted by an authored manifest. Generic Lua contract boards keep their main-orbital station requirement. The headquarters board is an explicit project extension; other researched RRS profiles remain queued. Compilation of the app does not establish native gameplay or full quality acceptance: consult [current mission status](MISSION-IMPLEMENTATION.md) and the [qualified ledger](WHOLE-APP-REMEDIATION.md).

The `native_station` and `native_main_arrival` fields in native event/query snapshots describe observed facts. Reading, copying or saving those fields does not grant a current board, service, doorway or delivery authority. The native controller must authenticate actual docking or validated versioned restoration and bind current sealed contexts. Boolean dock flags, authored data, old serialized snapshots and raw Commander files cannot substitute for that boundary. RRS boards provide no general market, refuelling or equipment service. See [the native station boundary](PR-native-rrs-station-runtime.md) and [documents consumer](PR-rrs-documents-courier.md) for the exact source contract and adaptations.

## Repeatable contracts and clocks

For new board work, start with the [sample contract generator and handlers](mission-packs/scripted-contracts/scripts/main.lua). `[board]` declares an ID, title, generator, clock, refresh period and optional exclusive group. The generator returns offer rows in `data.offers` with `commands = {}`; it must not transfer resources. Native input supplies deterministic offer draws and destinations. Each row freezes its `key`, title, briefing, destination, reward, deposit, failure terms, duration and parameter map.

Reopening a current board retains its offers. Acceptance revalidates the actual station, board revision, available offer, exclusive group, funds and physical fit; it creates an identified instance and runs `mission.accepted` with frozen `world.contract` terms. The sample additionally requires a direct jump with sufficient fuel. A refused acceptance does not consume the offer or leave a partial deposit/payload transfer. Repeatable work creates new instances and receipts; do not revive a terminal mission or reuse an old receipt as new payment.

Hand in or cancel the exact instance's cargo through its actual contact. `mission.finish` settles the contract's frozen native financial terms. The sample uses `complete`, `failed` or `abandoned` and distinguishes late hand-in from cancellation; a timer notice alone does not surrender its payload. Preserve the example's native confirmation and origin/destination checks when adapting it.

| Clock | Current meaning |
| --- | --- |
| `local` | Loaded, unpaused play, including station/contact activity; title, demo, game over, Gallery, Library, Help and navigation freeze it. |
| `flight` | Eligible unpaused flight; docking and modal mission/other excluded panels freeze it. |
| `calendar` | Persisted commander calendar with native launch/jump adjustments and its own panel-freeze policy. |
| `missionCalendar` | Native generated courier profile clock; requires the supported courier declarations, not an arbitrary timer domain. |
| `transit` | Reserved for actual admitted native transit; ordinary mission timers do not advance it. |

No clock here is offline wall time. Calendar launch adds 600 seconds; an admitted completed jump adds `distance² * 3600` seconds using the current original-world Cartesian light-year distance, without BBC coordinate conversion. Do not use a fixed number of rendered frames as a deadline. See [clock advancement](../Sources/L337Core/ScriptDirector.swift) and [calendar policy](../Sources/L337Core/ScriptCalendar.swift). Generic contract deadlines and the bundled courier's inclusive confirmation deadline have distinct native policies; retain the policy of the example you adapt.

The bundled courier uses a closed native profile, frozen route/reward terms and identified data/package custody. Its handlers use `courier.issue`, `courier.deliver` and `courier.abandon`, not generic payload/payment commands. Its balancing and duration text explicitly labels project estimates; it is not a general promise of recovered server behavior.

## Choices, receipts and campaign ownership

A dialogue supports up to eight declared choices. Choices sharing a `group` require `exclusive-choices-v2`; Confirm records one permanent branch receipt for that instance/group. Choices without a group require `dialogue-choices-v2`; each confirmed answer gets its own durable sequence receipt and can be asked again while the mission remains active. A dialogue cannot mix independent and grouped choices. Include `choice_id = event.choice_id` in `dialogue.commit`; [station conversation](mission-packs/station-conversation/scripts/main.lua) demonstrates repeatable answers and `answerRequirements`.

Installed `dependencies = ["pack.id@1.0.0"]` ensure content availability, not completed work. `receiptRequirements` select genuine terminal receipts by exact definition/version/digest, outcome and optional branch. Compound outcome requirements additionally use `compound-receipts-v2`. Reading a briefing, setting Lua data, or receiving an unrelated actor event cannot substitute for those receipts.

For owned campaigns, declare exact `[[children]]` pins and request `child.ensure`. Native code retains the parent/root/child relationship and does not start a second child when the request repeats. Scope a receipt requirement with `child = "alias"` so only that parent's actual child can satisfy it. A standalone patrol's completion cannot close another campaign's debrief. `parentOnly = true` restricts a child to owned acceptance. Child terminal policy is explicitly `suspend` or `preserve`; parent termination does not silently delete protected child property. Depth is bounded to four child levels, with at most 32 children per instance and 128 mission instances overall.

## Sandbox, persistence and limits

Each evaluation creates a fresh Lua interpreter. Persist progress only in returned `data` and native receipts, not globals or closure caches. The host exposes a restricted base/math subset, with ordered `ipairs` traversal and native deterministic inputs. It does not open I/O, OS, package, debug, coroutine, string or table libraries; `pairs`, `next`, loaders, metatables, `pcall`/`xpcall`, printing and `math.random`/`randomseed` are unavailable. `tostring` accepts scalars only. Declared `[[modules]]` with `pack-modules-v2` provide a closed pack-local `require` map; undeclared or cyclic imports fail.

Resources must be regular files with canonical relative paths, at most eight path components; symlinks and traversal paths are rejected. Each file and the combined module source have a 256 KiB limit. Lua source is UTF-8 text without NUL bytes; bytecode is not accepted. Default evaluation budgets are 50,000 instructions, 8 MiB live heap, 32 MiB cumulative allocation and 512 KiB output. A result has at most 256 commands; its returned data map must fit 256 KiB, finite numeric values and the bounded value nesting/item count. A manifest has 1-64 handlers, 1-64 milestones, at most 64 dialogues and at most 16 auxiliary modules. See [evaluation](../Sources/L337Core/ScriptEvaluator.swift), [value encoding](../Sources/L337Core/ScriptValue.swift) and [sandbox implementation](../Sources/MissionScript/MissionScript.c).

Saves retain exact content identities, instance data, native receipts and relevant physical world/custody state. Keep the commander save and its associated `.missions` directory together, and retain the matching pack folders separately when moving computers. Missing, changed or incompatible content suspends work while preserving its property; restoring exact content and using the supported Resume action retries pending work. Loading does not intentionally reissue acceptance rewards or replace progress with a fresh mission. Changing identity/version/digest requires an explicit supported migration; renaming an active mission to bypass checks is not a migration.

## Check an adaptation

Inspect startup errors and availability first. Test acceptance and refusal with real resources; Confirm and Back; wrong station and stale dialogue; save/reload with the same content; missing-content suspension and restoration; and each genuine terminal outcome. For encounters, prove actual admission, combat and return to the required station through native gameplay. For boards and campaigns, test independent instances and foreign receipts. Gallery trials help exercise a declared setup without spending the live commander's property, but are not full CI or historical parity evidence. Repository changes still require the normal `make ci` coverage, sanitizer and leak gates and the project's completed PR review cycle.
