# test(work): restore residual boundaries through current saves

## Changes

The residual-boundary test previously passed a current owned Commander to the legacy-only direct load API. It now captures the actual successfully docked scene, writes it through the canonical runtime and restores the real strict versioned generation. The original NaN failed snapshots, actual repair/dock/launch/arrival and momentum assertions remain, with complete captured Commander conservation added to both failed boundaries.

The independent expected Commander starts from the pre-save docked capture, allowing only supported equipment preparation/mirroring and explicit current mining storage. Source guards preserve nonempty ordinary salvage identities/bindings, native station and calendar state, original inventory/history/cash/cargo, and require an empty live scene/NPC ledger with no EMP/alien or active mission state. No loaded or published actor result becomes a semantic oracle. Empty-body native persistence and restore paths retain those ledgers without reallocation or normalization beyond the audited fields.

The actual publication must have commander scope, typed schema 26, a valid generation, four exact chunk names and hashes of their actual bytes. Strict reading must reproduce the full independently expected Commander and every pre-save world value. The original current Commander then receives an explicit raw-load refusal with unchanged Commander/world and residual/autopilot/velocity/pause/tool state. Actual runtime restore must return the complete saved scene, genuine docking and zero residual/autopilot/world velocity. The pointer, each chunk and generation/chunk inventories remain unchanged after `persistMigrations:false` loading. No fake success flag, downgraded property or weaker admission guard is introduced.

## Scope and verification

The exact parent is `91ee7560f5199e756dc88bfe1947d54a33781e97`. Three files change: `FlightWorkGuidanceRuntimeTests.swift` and this issue/PR pair. Only `successfulBoundariesClearResidualAndFailedSnapshotsPreserveIt` changes and becomes `async throws`: one existing method/one case, no new test or helper. All original bytes outside that method, shared fixtures, other work tests, EMP tests and production remain unchanged. All prior refs are preserved.

Only source formatting/parsing, strict lint, Markdownlint and static scope/assertion-effect/source/selection/hash checks run. No compiler, typecheck, discovery, tests, build, native/UI/media, GitHub, push, merge or Sonar jobs run. Root review and G1 execution remain outstanding; validation 348's separate crash is outside this leaf and no pass is inferred from authoring checks.

Eventual PRs require completed clean `@codex review` cycles, fixes and repeat review for every actionable finding, required final-head checks and approval, and protected merge without bypass.
