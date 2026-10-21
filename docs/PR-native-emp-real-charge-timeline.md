# Drive actual native EMP charging and saved crew ejection

Only the existing `nativeEMPKeysDisableEjectAndPublishTheSameSourceAndPeople` method and this pair change. The shared `empFixture`, production code and two full-stock travel scenarios remain unchanged. The UI scene retains SH023, hull 77, food two, crew one, identity and its existing orientation/velocity setup. `NPCResources.absorb` removes each authored facing's charge with zero hull overflow. `ElectricalReserve.drain` leaves positive one, with no disabled timestamp, EMP source or archive. Full NPC capacity/recharge and unchanged player fittings remain authoritative. The independent charge feasibility inequality is explicit.

After strict save/load, the original powered actor and saved seed/counter are required. Native W selects EMP. Native Return remains held through exactly one hundred subsequent 0.1-second frames after its initial charging frame. Pre-warmup frames must produce no EMP archive or audio. The actual release must occur after ten simulation seconds and emit once; key-up follows it. An independent per-frame integration of the original native hull recharge retains the no-fatal-EMP-damage oracle. Original source and occupied-cue pixel checks follow.

The current SH023 operating complement is one. The genuine first LCG draw from the saved input seed zero is zero, producing the actual 0.5-second sampled ordinal-zero delay. The test requires that saved episode and the resulting RNG state one rather than writing any crew flags or times. Native frames continue only until the actual original person ejects, with a hard thirty-second disabled-window limit. The original pod count, empty orange cue, actual F/Tab approach, 2,400-frame hold budget, 1,200-frame cutter budget, exact cargo-section depletion, food pending-plus-hold conservation, crew history and strict ordinary schema-26 save checks remain.

## Random-consumer proof

All production `randomByte()` call sites were read. Native W/Return and drawing do not select system-data clues (`Game.swift` 956), arrive or rebuild the market (1352). The saved mission counter begins at zero and wraps only on frame 256, after the charge's 101 frames; no Constrictor/plans mission is active. `navalTactics` reaches its draw only for qualifying low-energy craft with positive missiles; this scene and any admitted actors must retain zero missiles and no Blackjack role. There are no player-fired missiles; both naval missile and gameplay ordnance ECM draws require actual ordnance and an ECM-capable target, which are required absent. The ordinary encounter director has its own `EncounterRandom` state and cannot consume this LCG. Actual saved seed zero is checked on every frame before the first release, so an unexpected consumer fails the test rather than silently selecting or forcing a favorable result.

## Validation

Source formatting/parsing, strict lint, Markdownlint, whitespace and frozen scope/hash checks precede review. No compiler, native test or UI run has occurred for this leaf. The current 339 failures and 340 diagnostic artifacts remain preserved. Source review and coherent affected execution are required; no full-stock combat, full CI, sanitizer, leak or release acceptance is claimed.

[Issue](ISSUE-native-emp-real-charge-timeline.md).
