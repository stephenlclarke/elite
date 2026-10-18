# Align isolation and reset fixtures with canonical save publication

## Recorded problem

Full CI 328 at `901f75fc58412b7a6caf5d63e4010b4cf59e0f4f` recorded a live-commander equality failure in `contractTrialsKeepTheLiveCommanderWriterAndCargoIsolated`, then stale no-calendar/native-only expectations and raw Commander decoding failure in `gameOverReturnReplacesBoundDurableSaveWithClearedNativeCommander`. The run failed; its independent production stack failure remains G1-owned. No passing result is inferred from partial execution. The adjacent failed-reset retry shares the same source oracle but is not claimed to have executed or failed in that run.

## Cause

The contract test captures its commander before `save`, but saving publishes canonical equipment, mining-policy and calendar state back to the live runtime. Trial isolation must compare against the actual saved live state, with explicit original name, credits and cargo invariants.

Game-over reset creates a new commander and clears mission state. The canonical writer then persists the current economy mining policy and installs a new-commander calendar, selecting a schema-26 versioned save. Empty raw state and raw Commander decoding are obsolete fixture expectations. The fresh engine must contain exactly the legitimate calendar baseline and no old mission state.

## Required correction

Change only the three identified test methods, a shared pure expected-state helper and the matching documentation. Preserve whole-commander, cargo, isolated trial writer/file, reset rollback, controls, exact prior bytes, new-commander property and reload checks. Use strict pointer and generation reading with the exact schema and fresh state; do not add a raw fallback or weaken any versioned/raw/header guard. See the [PR handoff](PR-script-save-fixture-baselines.md).

Focused validation 329 passed all eighteen methods/twenty-four expanded cases on composed source `43dbe2591b063aee856a2484c3b84693bcb55d50`, using the original coverage-enabled debug/default-parallel configuration. This includes the actual stack-crash regression, all nine native admission methods with seven spawn-forgery cases, completion rollback/timing, choice/conversation behavior and the three trial/reset fixture methods. Test duration was 17.628 seconds, command 50.069 seconds and outer supervision 50.910 seconds. All selected starts/passes, 2,077 committed inputs, protected Commander/preferences and owned process closure were verified; no issues, signals or matched crash were reported. Exact coverage binary `955f50d5beeedd2b0d65f9f913712295572f22b9a4e6096fe11d4cf817b29270` is preserved in `/tmp/elite-script-event-stability-focused-329/compiled-snapshot/EliteCoreTests`. Raw log SHA256 `e8256896cf9c891a4f5e333bfdc7ca6392addbf609c744453e106cfd0f05de0f`. The generic supervisor's inherited TSan wording is explicitly qualified in the evidence: 329 ran coverage, not TSan. Full maintained CI remains outstanding.
