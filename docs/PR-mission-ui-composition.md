# feat(ui): compose mission screens and native menu intents

## Problem and result

Mission engine pages need routes through the current UI. Add contract/library presentation and navigation routes, campaign-aware gallery rendering and selection, contextual help, and a retained main-actor native menu target that emits typed intents without changing the commander.

## Implementation

`MissionUIAction` centralizes menu titles, availability and exact-page requirements. `MissionUIIntent.isCurrent(in:)` rejects changed screen, inventory context, ECM epoch and page proofs before actor dispatch. `NativeMissionMenu` installs explicit menu items without keyboard equivalents, preserves existing items and validates availability against the latest snapshot and requires an explicit matching actual-painted-page proof for contracts, Try and Retry. Gallery replacement keeps legacy identifiers and actual saved-instance/template identities stable before clamping removed selections.

The accepted `ContractBoardDisplay.swift` and `ScriptLibraryDisplay.swift` are already present at the base and are reused without modification. Existing finite-mesh projection, inventory interactions, fonts, HUD and flight controls are preserved.

## Integration

Follow `MISSION-UI-INTEGRATION.md` in this directory. The isolated slice intentionally does not edit the G1-owned `Game.swift` or `EliteApp.swift`; it requires their accepted mission state, screen cases, actor dispatch and native event-loop hooks. Base: `015fc95d92d64247559c00491b94b5d9304cde75`. Accepted mission API reference: `d12311d8fca20277aefc150f487acafb7377b0e4`.

## Validation

Authored `MissionUICompositionTests` and `NativeMissionMenuTests` cover availability, read-only library return, current numbered navigation, stale epoch/availability, responsive routes, native menu idempotence, preserved accelerators and captured proof. Review follow-up adds successful trial-start/return parent-intent refusal despite the same restored screen/ECM epoch, same-epoch screen changes, and painted/latest mismatch, absence and bounds refusal. Formatting and `git diff --check` pass. Tests, compilation, native interactions, sanitizers, coverage and leak gates are unexecuted under the active shared lease. Run focused tests after composition, then the shared `make ci` lane. Independent review remains required.

## Links and risks

Related issue: `ISSUE-mission-ui-composition.md`. The main risk is incomplete actor/native integration: do not expose menu entries through raw unguarded dispatch. Native painted-page keyboard and pointer proofs must be retained alongside the existing inventory and commander-file queues. No PR is created or published by this slice.
