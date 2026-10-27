# Save fixtures must preserve native scenes and account for real rebindings

## Diagnostic evidence and cause

Diagnostic 203 reports full-Commander equality failing in `xyzzyJumpLimitsPersistAndObeyCurrentFuelAndNavigationComputer` and `.invalidScene` in `timedMissionFailureStaysFailedAfterDockAndReloadWithoutPayingAReward`. The latter deletes the live station scene after launch and later changes the Commander system directly, leaving the retained station world and physical anchors inconsistent. The former compares pre-save native station bindings with loaded state even though the loader intentionally allocates fresh physical station actors and rebinds their ledger records in the same visit.

## Required correction

Retain the timed failure fixture's actual scene and original tick, then perform an actual arrival at system 129 before docking. Derive the jump-limit test's expected station world from its original saved world, changing only current living bindings proven against restored physical actors in the same visit. Preserve every other native-world field and the complete Commander equality assertion. No scene/save guard exception or removal of an equality field is appropriate. See [the implementation](PR-save-scene-fixtures.md).

## Scope and validation

Only the two named methods and a private expectation helper change. ScriptIdentity historical schema setup remains separately owned by the integration chat. Source reversal and strict lint/diff checks pass. No build, runtime or native execution occurred here; diagnostic failures remain failed evidence until validated corrections complete.
