# test: compare combat timelines at a genuine common cold boundary

## Resulting test behavior

The original uninterrupted hundred simulation steps still run without a load. Afterward, their actual endpoint is saved to a second file in the already owned temporary test directory and loaded into a fresh reference runtime with persistMigrations false. The early-resumed timeline still performs its original hundred steps. The original four complete body, Commander, native simulation RNG and loop-counter comparisons then run verbatim between those two native cold-bound references.

A new non-inline guard, used only by this method, independently checks that the late load preserved every non-RRS body, including mission and ordinary combat identity, tactics and physical state. It checks body count, game time, RNG and loop counter without stepping the simulation. An independent copy of the hot flight allocator reserves precisely one station spawn and actor; full cold flight state must equal that expected state. The actual station retains its stable identity, geometry, orientation, rotation and energy, while its new body/actor/spawn and ledger binding match the authoritative fresh-binding policy and expected cursor. Read-only Commander access avoids extra whole-Commander temporaries in that guard.

No actor is removed from the original full-value comparisons. No resumed output is copied into the reference. No production load/rebind helper is called to manufacture an expected value; both endpoints use the real public save/load path, with explicit late-load invariants guarding its effects.

## Source proof and validation

Source evidence `/tmp/elite-db650-cold-rng-source-proof/SOURCE-PROOF-AND-MINIMAL-PROPOSAL.json` SHA256 `563aba996f7052dd58a75dc8b5be2e533ab6ae053e964244d3f57c61c6e26a6e` ties the existing raw difference to GameRuntime.load and NativeStationRuntime.rebindNativeStationsAfterLoad. Existing NativeStationPersistenceTests independently asserts the same fresh actor/spawn/body policy. The new guard does not broaden CurrentNativeSaveTestFixture or invalidate its existing consumer qualifications.

Exactly one test file plus paired notes, one existing method/case, on db650c739fed9cffe65aae35bfda6e25eb42ac09. Strict Swift formatting, Markdown lint, whitespace and complete-file/original-oracle conservation checks precede freeze. One independent complete-method/helper review and matching warm build precede the actual case; it can join another ready union without repeating retained unrelated passes. Author compiler/build/test/probe execution is absent. The raw SIGBUS and global quality/review gates remain open; this is no crash fix claim. See [motivation](ISSUE-hosted-native-cold-reference.md).

## Matching compiler corrections

Build1041 stopped before tests because mutating allocator calls were placed inside Testing requirement macros. The first bounded correction moves each allocation into an ordinary optional let before requiring its value, preserving spawn-before-actor order. Build1043 then stopped before tests because Testing macro autoclosures captured borrowed Game parameters. The coherent correction audits the whole guard: every comparison is evaluated into an owned Bool and every optional lookup into an owned local before a macro receives it. Combined predicates are split into equivalent separate expectations. Borrowing signatures, all original predicates/allocation order, both timelines and the original four complete-value oracles remain unchanged. No owned whole-Game fallback, production edit or guard relaxation. Actual failed build logs and process closure remain retained; no runtime case ran in either failed build.
