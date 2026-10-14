# feat(missions): add the Lua mission runtime foundation

## Motivation and behavior

The owner requested a generic Lua mission engine on a new branch. The first implementation adds an authored scripted courier with no mission-specific Swift, preserving the three bundled schema 1 campaigns. Full physical/custody/campaign engine implementation remains in progress; this is not a claim that all researched missions are playable.

## Implementation

SHA-pinned vendored Lua, C-only protected/budgeted host, explicit serializable data, strict schema 2 folder loading and immutable installation, capability gates, typed in-memory commander transactions, station Confirm, local/flight timers, native Gallery references, isolated trial runtimes and immutable hashed save generations. See [API, limits and remaining work](SCRIPTABLE-MISSIONS.md).

## Validation

Full `make ci` passes: 244 tests in each coverage/thread/address lane, 93.09% maintained-code coverage, 94.57% new script Swift coverage, 94.62% maintained C-host coverage and 0 leaks. [Machine-readable evidence](SCRIPTABLE-MISSION-VALIDATION.json) pins the validated source bytes. Markdown and relative-link checks pass. Unmodified Lua is excluded from maintained-code coverage and analysis scope, while the custom host remains included and compiled Lua participates in sanitizer/leak execution.

## Compatibility and risks

Schema 1 and legacy IDs remain unchanged. Scripted saves require their pointer and `.missions` sidecar; old commander JSON imports remain supported. New native physical/custody/board/world-job capabilities are unavailable until implemented. Automatic durable Confirm, complete physics saves and migrations are outstanding. Branch is not merged or released; authoritative Sonar publication waits for committed main.
