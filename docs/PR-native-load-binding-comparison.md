# fix(save): compare native load changes using the writer's binding projection

## Change

The current native writer and public versioned load comparison share the same clearNativeSaveBindings operation. It performs exactly the existing ordinary NPC physical-binding reset (only for a nonempty ledger) and wanted-career binding reset. Live state is never normalized by this comparison. All snapshots, historical records, resources, counters, revisions, ordinary NPC semantics, station bindings and other Commander fields remain part of equality. Real current-format changes still cause publication.

The comparison's Commander copy lives in an explicit noninlined helper and returns before the load writer begins. It introduces no whole-Game copy, actor hop, cache, migration, acceptance receipt or authority. The actual write path and current-format validation are unchanged. The previous writer reset sequence is factored without semantic changes.

## Regression and evidence

The existing PLUGH discovery/current-save/galactic-departure regression now captures its live oracle after successful save. It independently reads the actual versioned Commander and checks the writer's established disk binding projection, requires exact full live Commander preservation after ordinary default public load, and retains the exact pointer-byte assertion. Equipment and PLUGH identity/departure checks remain unchanged. No read-only flag is used to make the pointer assertion pass.

Actual655 recorded failures at PlughTests155/156 before a separate native-transit stack crash; this source change is based on the concrete save/load projection mismatch and invalid pre-save oracle, not a new successful run. Strict Swift formatting/lint and whitespace checks are the only author validation. No compiler, native test, GUI, debugger or profiler job ran. G1 must execute the existing regression with the material transit crash repair; native/runtime acceptance remains pending. Author artifacts are isolated under /tmp/elite-root-plugh-655 and canonical files remain untouched until central integration.

## Scope and risk

Only the versioned load comparison and the writer's already-existing binding projection change. Raw/legacy readers, stock/equipment/migration policy, native RRS authority, frame clocks and transit behavior are untouched. Existing current-save corruption checks and real semantic re-publication must retain their behavior. This is an intended redundant-write optimization, not a measured performance claim or a full game-completion claim. No GitHub issue or PR is created. See the [source issue](ISSUE-native-load-binding-comparison.md).
