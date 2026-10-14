# TOML mission packs

Schema 1, engine contract 1.0.0. The three bundled playable campaigns and the external courier example use this format. Existing researched packets remain evidence, not installed missions.

A pack is one UTF-8 `.toml` file, at most 256 KiB, containing one mission. Install through **Commander > Install Mission Pack...** or place the file in `~/.xyzzy/elite/mission-packs/` and restart. The engine validates content before enabling it. There is no executable scripting or file access in a pack.

Validate with `swift run Elite --validate-mission-pack path/to/pack.toml` or `make mission-packs-check`. The complete minimal example is [courier.toml](mission-packs/courier.toml). Bundled campaigns live in `Sources/EliteCore/Resources/MissionPacks/`.

## Identity and compatibility

Root keys: `schemaVersion = 1`, `id` (lowercase dotted stable ID), `version` (three-part semantic version), `minimumEngine = "1.0.0"`, `capabilities`, `dependencies` (optional exact `id@version` strings), `priority` (0-1000, lower first), `source`, `license`. The `[mission]` table has `id`, `title` (1-32 characters), `initialStage`, `briefing`, `destination`, `reward`, `prerequisites` and `milestones`. The qualified persistence key is `pack.id/mission.id`; never reuse IDs for a different campaign.

Capability names: `state-machine-v1`, `dialog-v1`, `economy-v1`, `cargo-v1`, `clock-v1`. Bundled legacy campaigns additionally use reserved engine bindings for their existing encounter and custody primitives. External packs cannot request those bindings. New AI, passenger cabins, crew, station boards, storage and arbitrary new ship spawning are not supported by schema 1.

`[[stages]]` has `id`, `objective`, `completed` (milestone count), `terminal` (optional). `[[transitions]]` has a stable `id`, `from`, `event`, `to`, optional `conditions`, `actions`, `dialog`, `confirmation` and `notification`. Transitions are checked in file order; at most one per mission per event, with no recursive dispatch. Pack ordering is priority then ID. A displayed dialog stops further contact offers for that event.

Events: `dock`, `contact`, `targetRemoved`, `targetDestroyed`, `clock`. A `confirmation = true` transition opens its dialog on dock/contact and commits only on Confirm after rechecking conditions, stage and location. Back does not commit. Automatic dock transitions commit before showing their message. Target events are emitted only after engine identity validation; reserved encounter bindings preserve original NPC custody and combat behaviour.

## Conditions and actions

Conditions are an AND list of inline tables: `{ field = "galaxy", op = "eq", value = 0 }`. Operators: `eq`, `ne`, `lt`, `le`, `gt`, `ge`. Fields: `galaxy`, `system`, `x`, `y`, `kills`, `credits`, `legal`, `mainStation`, `freeTonnes`, `stageSeconds`, `navalStage` (bundled only), `flag:NAME`, `receipt:NAME`, `payload:NAME`, `cargo:INDEX`, `target`. Booleans use 0/1; target values are strings in `text`, numeric fields use `value`. Galaxy/system IDs are zero-based. Flags and receipt names are local to this mission.

Actions are an ordered list of inline tables with `kind`, optional `key`, `amount`. Kinds: `credits` (tenths of CR, checked), `creditsWrapped` (bundled original 32-bit semantics), `killsWrapped` (16-bit), `legalSet`, `legalFloor`, `equipmentAdd`, `equipmentRemove`, `flagSet`, `receipt`, `cargoAdd`, `cargoRemove`, `cargoRewardOrPending`, `payloadAdd`, `payloadRemove`. `cargo*` uses commodity index in `key`; cargo reward overflow sets `pendingGold` for the legacy pack only. Payload amounts are tonnes, reserved against hold capacity and stored separately from saleable commodities. Transactions apply to a copy and commit atomically with the stage and receipts; failure leaves the mission and commander unchanged.

`[[dialogs]]` contains `id`, `text`, optional `ship` and `delaySeconds`. Text supports `{commander}`, `{galaxy}`, `{kills}`, `{constrictor}`, `{captain}`, `{sighting}` substitutions for the original naval messages. The original font and game-rendered Confirm/Back controls are retained. A `clock` transition can use `stageSeconds` for a deadline: time is persisted, advances only during unpaused flight simulation, and freezes in read-only panels and dialogs. Dock arrival is processed before a subsequent clock event.

## Saves, missing packs and updates

Saved state includes pack version/content digest, stage, elapsed stage flight time, flags, once-only transition receipts and unique payloads. Legacy naval TP and Blackjack stage/transfers/unique target UUIDs remain compatible. A read adapter maps every legacy stage to the pack stage; the first new transition persists that imported state with its atomic receipts. Reading an old save does not add empty state or rewrite its file. Loading a save never replays transition actions or rewards.

Missing packs leave their saved state and payloads intact and suspended. Reinstall the same file to resume. A different version or digest cannot run against existing progress: the player must retain the matching pack; automatic reset or guessed migration is forbidden. Installation rejects duplicate IDs, unsupported versions/capabilities, missing exact dependencies, invalid references and unsafe file types. Updates with active saved progress require a future explicit migration format; this release deliberately does not guess stage mappings.

Research handoffs should retain source evidence and list unsupported engine mechanics separately. A valid TOML file is not evidence that a researched campaign matches the original; scenario parity still needs source-backed tests.

## Bounded format and original campaign bindings

IDs are 1-80 characters: lowercase letter followed by lowercase letters, digits, dots or hyphens. Local flag/receipt/payload names may also use uppercase letters. Each pack has 1-64 stages, 1-128 transitions and 1-64 milestones; each transition has at most 32 conditions and 32 actions. Dialogs contain at most 12,000 characters; long messages scroll with Option-Up/Down or the trackpad. Unknown keys, malformed references, unsupported target events and missing capability declarations are rejected. Transition IDs are once-only: deliberate repeatable contracts need a future instance/receipt model, rather than a loop that reuses an ID.

Reserved bundled-only fields are `mission.binding` (`naval` or `blackjack`), stage `legacyValues`/`legacyWrite`, `[[clues]]` (`galaxy`, `systems`, `texts`) and `[[encounters]]` (`id`, `stage`, optional `galaxy`/`system`, `kind`). Kinds bind existing `constrictor-hunt`, `plans-ambush` or `blackjack-target` mechanics; they are not arbitrary script hooks. Campaign qualifications, stages, location gates, messages, clues, reward amounts and transfer progression live in the TOMLs. Swift retains identity validation, the original encounter probability/byte rules, finite AI/combat, marked-firearm custody, wanted enforcement and original register arithmetic. Numeric NPC/geometry data continues to come from the ship folder. No new research campaign or encounter type is implicitly enabled.

Commander saves are bounded to 4 MiB to accommodate installed pack progress. Missing or incompatible packs appear suspended in the Gallery; invalid installed files produce an actionable startup alert. A conflicting ID/dependency set disables all external candidates for that load; bundled campaigns remain available. Dependencies are exact installed pack versions, not automatic completion prerequisites. The installed pack files are local to this Mac and are not embedded in commander saves: move matching TOMLs with your save when changing computers.
