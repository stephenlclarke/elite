# Native salvage save expectations omit wanted and station binding phases

## Actual1046 evidence

The composed run completed with42 methods/64 cases passing and exactly two native salvage methods failing at three full-commander comparisons. Both disk comparisons expose three wanted careers whose actual saved craft bindings are nil while the expected disk values retain actor2/6/7. Source-aware parsing of existing printed data preserves ordinary array order and identifies the remaining equipment/inventory/NPC/salvage differences as typed set or dictionary ordering. The cold awaited equality prints no actual field values, so its exact observed field difference is unavailable; do not report one.

## Source cause and minimal scope

The actual writer clears both NPC scene bindings and optional wanted-career craft bindings on the disk copy. The two independent disk builders clear only NPC bindings. Actual cold load authenticates and restores the retained ordinary NPC scene, reconciles wanted careers, then allocates a fresh spawn and actor/body binding for each retained RRS station and updates the commander world/flight counters. Comparing to the untouched pre-load commander incorrectly requires old station bindings.

The full CurrentNativeSaveTestFixture cannot be reused: it rejects alienStorageState, which these actual recovered-module cases require. Keep that guard and all production/helper behavior intact. Add wanted reset to the two local disk expectations, and derive a full independent cold commander before loading from the original post-collection scene plus existing allocation/rebind domain primitives. No observed saved/loaded output supplies expected facts.

## Ownership and acceptance

Root assigns G2 exactly the two failing methods and one sole-use private cold helper in NativeSalvageCollectionRuntimeTests.swift plus paired notes, isolated child of5e5c9590. All other source and the passing42/64 remain untouched. One independent complete-delta review precedes G1 matching compilation and only these two cases. No author compiler/build/test/probe/runtime or shared fixture/production changes. See [handoff](PR-salvage-save-binding-expectations.md).
