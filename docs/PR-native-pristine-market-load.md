# fix(save): avoid recording an unchanged market during restoration

## Change

restoreScriptWorld writes its saved market only when it differs from the actual currently resolved market. This keeps an unchanged pristine market represented by its authenticated seed rather than introducing owned state during load. A genuinely different saved market still goes through the existing setter. No quote, stock, seed, validation, save-publication or trading policy changes.

## Regression and evidence

Retain plughDiscoverySaveValidationAndGalacticDeparturePreserveIdentityAndEquipment unchanged: it compares the complete post-save live Commander after ordinary default public load, the independently read disk projection, and exact pointer bytes. Actual659 failed the full live comparison and pointer equality. Its retained diagnostics and direct restore/setter source join establish the redundant market insertion; no new diagnostic execution was needed. Existing original-world changed-stock persistence coverage remains applicable.

This handoff contains source only. No compiler, native test, UI, debugger or profiling job ran. Elite Coder 1 owns combined execution with the separate material native-transit stack repair. A reviewed patch does not establish runtime success or a new usable application.

## Scope and risk

Only the restoration assignment changes. Current-format validation, real semantic republication, NPC binding restoration, native station/transit state and public-load defaults remain intact. No compatibility layer, migration, equality waiver or test suppression is introduced. Author artifacts are isolated under /tmp/elite-root-plugh-market-659 against ba70799f8688d82bda53902a1bd21c0483c1ed1c. No GitHub issue or PR was created. See [the source issue](ISSUE-native-pristine-market-load.md).

## Latest central execution

Central run 661 at committed source c06c672a4e62f6e163d9ba36113c9dc918286774 completed all four selected methods and eight source cases with no errors, unknown outcomes, crashes or timeouts. The previously crashing unresolved-world request/save path, full PLUGH current-format live/disk Commander and default-public-load exact-pointer assertions, and all six basic/paid-extended route-pool cases passed. Evidence: /tmp/elite-station-qualification-661/agent-game-test-verification-661.json (SHA256 90facc6d3bd158fe34884a24357979f1c06e24b5be4d84826d1508f7918545f6). This is focused native evidence; earlier interrupted NPC departures, player cohorts and physics outcomes remain unqualified. Actual signed-app launch/save/load/hyperspace verification and final required gates are separate pending delivery steps.
