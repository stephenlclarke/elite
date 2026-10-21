# MBA review and unit queue

The live queue is [GitHub issue #23](https://github.com/stephenlclarke/elite/issues/23). Add one packet comment there when code is pushed. Findings use `mba-finding`; pushed corrections use `awaiting-mba` until the MBA independently verifies and closes them. Issue #23 is a coordination tracker and must not trigger defect remediation.

Follow [the developer/reviewer workflow](DEVELOPMENT-WORKFLOW.md). Do not maintain a second live status table in this file. The ledger records feature milestones; GitHub records review and correction state.

The historical baseline is `41c15aed9d2684cc2708077a16f6b8aef576be31`. Its original W04 runtime/journey selection was cancelled before any integration case ran. The replacement MBA task contains only these isolated `NativeUtilityCustodyTests` methods:

- `explicitWorldActivationOwnsEightMaterialsWithoutTargetDockAuthority()`
- `strictCurrentUtilitySchemaRejectsUnjoinedOrInventedClaims(fault:)` (15 inputs)
- `targetRequiresUtilityStateAndOtherStationsCannotClaimIt()`

This is three methods/17 cases, using in-memory models and JSON validation only. All Game/GameRuntime/runtime/journey methods are excluded. Cached build path: `/tmp/elite-MBA-baseline-41c15aed-20261021/build`; execution records: `/tmp/elite-MBA-units-41c15aed-20261021`. No result is inferred from assignment or process start. Post the actual result to issue #23.

No integration testing. The MBA may create requested image assets under explicit disjoint ownership, but code reviews and correction checks take precedence over optional asset work.
