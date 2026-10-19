# fix(save): avoid recording an unchanged market during restoration

## Change

restoreScriptWorld writes its saved market only when it differs from the actual currently resolved market. This keeps an unchanged pristine market represented by its authenticated seed rather than introducing owned state during load. A genuinely different saved market still goes through the existing setter. No quote, stock, seed, validation, save-publication or trading policy changes.

## Regression and evidence

Retain plughDiscoverySaveValidationAndGalacticDeparturePreserveIdentityAndEquipment unchanged: it compares the complete post-save live Commander after ordinary default public load, the independently read disk projection, and exact pointer bytes. Actual659 failed the full live comparison and pointer equality. Its retained diagnostics and direct restore/setter source join establish the redundant market insertion; no new diagnostic execution was needed. Existing original-world changed-stock persistence coverage remains applicable.

This handoff contains source only. No compiler, native test, UI, debugger or profiling job ran. Elite Coder 1 owns combined execution with the separate material native-transit stack repair. A reviewed patch does not establish runtime success or a new usable application.

## Scope and risk

Only the restoration assignment changes. Current-format validation, real semantic republication, NPC binding restoration, native station/transit state and public-load defaults remain intact. No compatibility layer, migration, equality waiver or test suppression is introduced. Author artifacts are isolated under /tmp/elite-root-plugh-market-659 against ba70799f8688d82bda53902a1bd21c0483c1ed1c. No GitHub issue or PR was created. See [the source issue](ISSUE-native-pristine-market-load.md).
