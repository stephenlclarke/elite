# Native salvage save expectations omit wanted and station binding phases

## Actual1046 evidence

The composed run completed with42 methods/64 cases passing and exactly two native salvage methods failing at three full-commander comparisons. Both disk comparisons expose three wanted careers whose actual saved craft bindings are nil while the expected disk values retain actor2/6/7. Source-aware parsing of existing printed data preserves ordinary array order and identifies the remaining equipment/inventory/NPC/salvage differences as typed set or dictionary ordering. The cold awaited equality prints no actual field values, so its exact observed field difference is unavailable; do not report one.

## Source cause and minimal scope

The actual writer clears both NPC scene bindings and optional wanted-career craft bindings on the disk copy. The two independent disk builders clear only NPC bindings. Actual cold load authenticates and restores the retained ordinary NPC scene, reconciles wanted careers, then allocates a fresh spawn and actor/body binding for each retained RRS station and updates the commander world/flight counters. Comparing to the untouched pre-load commander incorrectly requires old station bindings.

The full CurrentNativeSaveTestFixture cannot be reused: it rejects alienStorageState, which these actual recovered-module cases require. Keep that guard and all production/helper behavior intact. Add wanted reset to the two local disk expectations, and derive a full independent cold commander before loading from the original post-collection scene plus existing allocation/rebind domain primitives. No observed saved/loaded output supplies expected facts.

## Ownership and acceptance

Root assigns G2 exactly the two failing methods and one sole-use private cold helper in NativeSalvageCollectionRuntimeTests.swift plus paired notes, isolated child of5e5c9590. All other source and the passing42/64 remain untouched. One independent complete-delta review precedes G1 matching compilation and only these two cases. No author compiler/build/test/probe/runtime or shared fixture/production changes. See [handoff](PR-salvage-save-binding-expectations.md).

## Salvage save expectations qualified and held dependencies integrated

The final two NativeSalvage methods passed in actual run 1048: two methods / two cases, zero issues or unknown outcomes, native 11.214 seconds, inner 16.177 seconds and outer 18.543 seconds. Matching incremental build 1047 passed in 36.18 native / 38.454 outer seconds. All 1,955 guarded artifacts, tracked source and primary preferences remained exact; ten build and thirteen runtime observed process starts are independently absent, with no timeout or cleanup. The validation lease is released. Qualification SHA256 `94b1ad81fd0417d216e2b9a53bb5583e8ae9feb13861031d0c69f576e1068122`; closure SHA256 `2f188c5076b294a9ef871073c45521e1f620a6df88fb6d596e50856357029fc1`.

The reviewed correction independently derives native disk wanted bindings and cold station allocation from the original commander. Whole Commander, file bytes, original alien custody, writer refusal/retry and once-only assertions remain required. Independent correction review SHA256 `3e819936347ec26c2b8ac51337a44f9d814b6ce00913e10ac72aac3a33311ab9` is clean. The exact previously held MissionCanonicalEquipmentTestSupport and ScriptCommanderQuery source now integrates with the corrected NativeSalvage source and paired notes.

The changed 44-method / 66-case dependency union is locally qualified across retained 1046 passes (42 / 64) and corrected 1048 (2 / 2), rather than a single passing run. Earlier three geometry cases remain separately qualified and were not repeated. Original compiler/runtime/hosted failures remain preserved. Hosted Swift 6.1.2 acceptance, global coverage, sanitizers, leaks and the final-head required PR review/checks remain open. No production, preview runtime, media fingerprint input, merge, release or feature-branch Sonar change is included.
