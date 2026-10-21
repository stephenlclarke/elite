# Restore current work fixtures through their versioned save boundary

## Recorded failure and cause

Validation 348 recorded one issue in `successfulBoundariesClearResidualAndFailedSnapshotsPreserveIt` at `FlightWorkGuidanceRuntimeTests.swift:822`. The prefix `loaded && game.docked && !game.manualResidualFlight` was false; the velocity comparison was not evaluated. The method terminated after 9.693 seconds, but a separate EMP SIGBUS prevents overall batch acceptance. Raw log: `/tmp/elite-work-surface-and-cobra-focused-348/candidate-348-attempt-01.log`, SHA256 `4035035b0b1adda8a5e84396c0d16e4db3234031455bc19bffb40106d8cb6b65`.

At pinned source `91ee7560f5199e756dc88bfe1947d54a33781e97`, `workRuntimeGame` prepares current version-three ownership, grants actual targeting/work/scoop devices and launches. `releasedResidualGame` admits a real salvage lot and releases actual guidance momentum. The captured Commander therefore cannot enter the deliberately legacy-only `Game.load(Commander)` guard, which explicitly refuses modular drives and current mining policy. This source-backed admission mismatch does not demonstrate a residual-clearing regression, and the raw diagnostic does not isolate the `loaded` operand itself.

## Required behavior and normalization audit

Keep the captured current Commander, both intentional NaN snapshot failures, actual velocity repair, successful docking, launch and final arrival assertions. Strengthen the failed boundaries with whole original Commander preservation. After the successful real dock, capture that complete valid docked Game before saving or launching. Preserve all original owned inventory/history, cash/cargo, pending salvage identities and ordinary source bindings; never inject a flight Commander into an invented docked world.

The save source contains a nonempty ordinary salvage ledger, native station world and calendar. Require no live bodies, no NPC ledger entries, no EMP/alien state or active script instances/contracts. Empty live actors mean cargo/ore/salvage pose persistence and NPC/station rebinding cannot change retained records. With no alien storage, native hot salvage flush is empty. Existing calendar state stays intact. Derive the complete expected Commander independently from the pre-save docked capture, applying supported prepare/mirror and explicit current mining-ledger storage only. Require salvage, station and script state unchanged before publication; unexplained state is not erased or copied from an actor result.

Write that actual scene through `GameRuntime.save` to a private temporary destination. Require commander-scope typed schema 26, a valid real generation, exact four chunk names and actual hashes. Strictly read the complete expected Commander and every saved world JSON value. The expected world comes from the pre-save docked scene, whose empty body array excludes nested unordered Commander Sets.

Keep the original launch reset/speed/autopilot assertion. The original current Commander is explicitly refused by the raw boundary with unchanged Commander, world snapshot, actual velocity, residual/autopilot, pause and tool state. Restore the verified docked generation through actual `GameRuntime.load(persistMigrations:false)` and require complete expected Commander/world, real main-station docking, zero residual/world/autopilot velocity and cleared pause state. Require byte-identical actual pointer and all original chunks, with unchanged generation/chunk inventories. A fabricated success Boolean or manual motion reset is prohibited. Keep the final fresh residual fixture and actual arrival's exact momentum-to-speed assertion unchanged.

## Scope and validation

Only this existing method becomes asynchronous, plus this new issue/PR pair. One method/one case changes, with no new tests or helpers. Shared `workRuntimeGame`, `releasedResidualGame`, all other methods, production and G1's separate EMP investigation remain byte-identical. The exact parent is `91ee7560f5199e756dc88bfe1947d54a33781e97`; all earlier refs remain preserved.

Formatting/parsing, strict lint, Markdownlint and static assertion-effect/scope/source/hash/selection checks are the only local validation. No compiler, discovery, tests, build, native/UI/media or GitHub jobs run. Root reviews the frozen child before G1 integration/execution; no runtime pass is claimed. See the [PR handoff](PR-residual-current-save-restore.md).
