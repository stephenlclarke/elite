# EMP census validation overlaps dormant world-save consistency storage

At `7e906782dcd7be0b46376c1f551d956b8ba855c3`, build 479 passed, but the unchanged two-argument `empArchiveNestedTimerSavePublishesAndReplaysOnce` reproducer in run 480 faulted later during save validation. The live path is crew census, source/crew validity, EMP state/scene consistency, `consistentAfterNativeSalvage`, publication validation and the publisher. Run 480 records zero issues and one unknown method; it establishes no pass for that method.

Exact retained facts are `/tmp/elite-native-journeys-focused-480/census-publication-compiled-observation.json` and `agent-game-test-verification-480.json` in that directory. The post-salvage consistency frame has 136 stack-probe GOT relocations and six SpaceBody copy witnesses reserved while its initial EMP check is active. Those counts describe emitted sites, not aggregate peak bytes. Native salvage already runs first in its own caller boundary; the unrelated later station, UI, actor, projectile and journey buffers must not share the EMP validation frame.

Extract complete ordered categories, preserving the entire original consistency contract, exact full equalities, diagnostics/fallbacks, ownership and population/canonical checks. Actor duplicate detection must remain before projectiles even though its records are needed again after the calendar checks. Do not alter writer, transaction, EMP, Game, work-tool or test code, cache trusted state, copy Game/Commander, change schemas or increase stack/concurrency/budgets. G3 separately owns census internals.

[PR-world-save-consistency-lifetimes.md](PR-world-save-consistency-lifetimes.md).
