# fix(equipment): keep current validation outside migration candidate frames

`prepareEquipment` now validates an already-current version-3 commander with no legacy representation and returns before entering the owned Commander candidate helper. Every other path uses the existing atomic migration sequence in a non-inlined helper. `migrateStockHyperspaceDrive` retains its full validation and version guard, then enters a non-inlined allocating body only when migration is required. The migration body, validation implementation and publication order are unchanged.

This addresses the specific equipment frames reached by the unchanged run-457 durable timer crash. It adds no unsafe/reference state and changes no Game, Script, timer, purchase or save contract. Source changes alone do not establish the compiled stack reduction or resolve the cumulative caller stack.

## Validation

Authored focused regressions cover whole-Commander current no-ops with zero migration ID allocation; invalid current inventory, history, drive, ammunition mirror, effective/component statistics, unknown held items and mixed legacy representations; genuine historical version-2 migration; direct migration ID-collision rollback; and public preparation revision-refusal rollback. The existing independent pre-drive fixture verifies complete migration semantics. Existing version-1 finite-ammunition/final-drive rollback and owned-object migration tests remain unchanged.

Strict Swift formatting, Markdown lint and whitespace checks are source-only validation. No compiler, test, native, GUI, debugger or renderer jobs were run by this author. The integrator owns one coherent compile, compiled-frame observation and the original unchanged timer smoke before remaining affected acceptance. No native pass, measured peak reduction or whole-CI completion is claimed.
