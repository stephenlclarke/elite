# feat(missions): add Lua missions, physical encounters and isolated trials

## Motivation and behavior

The owner requested a generic Lua mission engine on a new branch. The implementation adds authored scripted courier, real classic patrol humanoid passenger equipment-loan and generated contract and profiled skirmish examples with no mission-specific Swift, preserving the three bundled schema 1 campaigns. Full source-specific physical/custody/campaign engine implementation remains in progress; this is not a claim that all researched missions are playable.

## Implementation

SHA-pinned vendored Lua, C-only protected/budgeted host, explicit serializable data, strict schema 2 folder loading and immutable installation, capability gates, durable staged commander transactions, station Confirm, local/flight timers, native Gallery references, player-facing isolated trials with restart/return/retry and scoped Save/Open and immutable hashed save generations; whole-cohort classic admission, stable actor identity/world records, true death versus removal, native completion gates and saved combat RNG/tactics; measured pinned NPC models/components, explicit NPC fits, bounded native steering, physical laser/plasma collision and saved live projectiles; identified equipment, surplus storage, owned refitting and scoped issue/return/release/consumption, saved main-station contract offers, native deposit/deadline/settlement, independent repeat instances and explicit native board UI, actual crew/physical cabin fit, uniquely owned empty cabin storage/refitting and native passenger delivery receipts. See [API, limits and remaining work](SCRIPTABLE-MISSIONS.md).

## Validation

Full `make ci` passes: 417 tests in each coverage/thread/address lane, 93.77% maintained-code coverage, 96.51% new script Swift coverage, 94.80% profiled NPC/collision coverage, 92.30% contract coverage, 94.85% charter/accommodation coverage, 94.97% equipment/storage coverage, 97.58% loan handling coverage, 95% maintained C-host coverage, 97.24% trial-runtime coverage, 100% durable-transaction helper coverage and 0 leaks. [Machine-readable evidence](SCRIPTABLE-MISSION-VALIDATION.json) pins the validated source bytes. Markdown and relative-link checks pass. Unmodified Lua is excluded from maintained-code coverage and analysis scope, while the custom host remains included and compiled Lua participates in sanitizer/leak execution.

## Compatibility and risks

Schema 1 and legacy IDs remain unchanged. Scripted saves require their pointer and `.missions` sidecar; old commander JSON imports remain supported. New native physical/custody/board/world-job capabilities are unavailable until implemented. Full source-profile physics/AI/custody/board/world jobs, complete controller integration saves and migrations are outstanding. Branch is not merged or released; authoritative Sonar publication waits for committed main.
