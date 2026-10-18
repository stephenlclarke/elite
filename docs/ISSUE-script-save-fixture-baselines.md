# Align isolation and reset fixtures with canonical save publication

## Recorded problem

Full CI 328 at `901f75fc58412b7a6caf5d63e4010b4cf59e0f4f` recorded a live-commander equality failure in `contractTrialsKeepTheLiveCommanderWriterAndCargoIsolated`, then stale no-calendar/native-only expectations and raw Commander decoding failure in `gameOverReturnReplacesBoundDurableSaveWithClearedNativeCommander`. The run failed; its independent production stack failure remains G1-owned. No passing result is inferred from partial execution. The adjacent failed-reset retry shares the same source oracle but is not claimed to have executed or failed in that run.

## Cause

The contract test captures its commander before `save`, but saving publishes canonical equipment, mining-policy and calendar state back to the live runtime. Trial isolation must compare against the actual saved live state, with explicit original name, credits and cargo invariants.

Game-over reset creates a new commander and clears mission state. The canonical writer then persists the current economy mining policy and installs a new-commander calendar, selecting a schema-26 versioned save. Empty raw state and raw Commander decoding are obsolete fixture expectations. The fresh engine must contain exactly the legitimate calendar baseline and no old mission state.

## Required correction

Change only the three identified test methods, a shared pure expected-state helper and the matching documentation. Preserve whole-commander, cargo, isolated trial writer/file, reset rollback, controls, exact prior bytes, new-commander property and reload checks. Use strict pointer and generation reading with the exact schema and fresh state; do not add a raw fallback or weaken any versioned/raw/header guard. See the [PR handoff](PR-script-save-fixture-baselines.md).
