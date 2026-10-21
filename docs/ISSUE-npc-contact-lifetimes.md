# NPC contact test retains unrelated verification lifetimes during impacts

## Evidence and scope

Diagnostic checkpoint 196 using the exact checkpoint 195 binary stopped on thread 48 in `componentRayHitsUseMeasuredGeometryAndCannotBecomeHullDeathOrPlayerBounty`. The captured stack passes through `verifyComponentRayContactsAndBounty`, `applyActualNPCLaser`, the actual mission impact pipeline and NPC profile validation to regex allocation at a guard-page access. The evidence file is `/tmp/elite-debug-crash-196/actual-stopped-thread.json`, with source `73ca30b5daba33b539e20d027cfd494356013036`. This does not establish equivalence to checkpoint 195 without its matching OS report.

## Lifetime hypothesis

The inout verification helper combines early measured contacts, component destruction and mesh assertions with later ally laser impacts and bounty assertions. The laser helper also retains source/target bodies and NPC fitting temporaries while applying the proof. Separate these phases without changing their operations so unrelated test temporaries need not remain in the same function during the deep impact call.

## Required preservation and limits

Preserve all original rays, measured distances, fresh sealed contacts and origins, actual fitted damage, loop counts, actual weapon proofs, impact projection, counters and final mission/bounty assertions. No production guard, boxing, stack option, serialization or test skip is justified by this hypothesis. Static checks and source reversal can confirm preservation, but compilation and the combined runtime gate remain with the integration owner. See [the implementation](PR-npc-contact-lifetimes.md).
