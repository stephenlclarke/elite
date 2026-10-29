# Atomic dock snapshot preparation

## Problem

CI612 retained Commander equality failures in SalvageWorldRuntimeTests.invalidLiveSnapshotCannotPublishPartialMotionOrConsumeTheGalacticDrive and FlightWorkGuidanceRuntimeTests.successfulBoundariesClearResidualAndFailedSnapshotsPreserveIt. Docking persists ordinary NPC, cargo and ore state before a later salvage snapshot can refuse. The fixture clears its launched NPC ledger but retains wanted bindings; ordinary reconciliation clears these bindings before invalid salvage motion refuses, publishing a partial Commander change. Subsequent arrival comparisons inherit that first mutation.

Review of the initial repair identified a source lifetime risk: retaining a full Commander local across the deep persistence chain overlaps another Commander snapshot in cold salvage persistence. A private synchronous reference owner must hold the same rollback values across those calls. This is a source lifetime finding, not a measured emitted-frame result.

## Required behavior

A refused dock snapshot preparation must retain the Commander and native salvage observations from the start of that preparation. Genuine death settlement and station condition observation remain before the preparation boundary. Successful docking retains the existing snapshot, parking, unbinding, mission and service order.

The capacity fixture must leave the current gossip board with Escape; Return opens a dossier. All current capacity, duplicate, ownership and malformed-input assertions remain strict.

## Validation and scope

Existing strict whole-Commander refusal regressions cover the reported mutation; their snapshots and assertions must remain unchanged. The successful dock and residual-motion assertions remain. No old-format support is added. This issue does not establish full CI acceptance or resolve the separately owned courier/procurement failures. See PR-atomic-dock-preparation.md.
