# Preserve native EMP coverage with explicit persistence preconditions

## Recorded premise failure

Root-reviewed validation 346 reported that the untouched full-stock launch Cobra reached electrical zero at physical time 21.8, while the player died later at 25.5 after the three-second wait and attempted departure. Retained threat evidence showed a police/security window at 25.5 with lawful authority and the original trader window at 21.8 only. Those windows are not per-hit damage history and do not certify the fatal hit. Stationary survival after assaulting a clean trader is not guaranteed; the game's police response must remain intact.

## Required paired coverage

The existing hyperspace/dock/save/reload persistence method starts with a genuinely admitted launch Cobra that already has nonfatal electrical damage. Before its original snapshot, resolve SH023 through the canonical native fallback, require the legacy-energy profile and catalogue recharge two, and use a supported electrical reserve at the unchanged physical clock. Drain it to positive one with no disabled marker. Only the resource's canonical legacy recharge cache and electrical reserve change. Require complete expected body-array equality, unchanged Commander/allocators, player energy/shields, RNG and clocks, and an unpinned catalogue ID before actual zero. No fabricated disablement, custody, crew, identities, health, law or controls are permitted.

Require the real P80 pulse and ten-second charge, with one actual discharge before disabling the damaged target. The independent bound `1 + 2 * (10 + 0.1) < 80` explains the controlled precondition; it does not promise a successful escape or test pass. Keep every original actual flight, fuel, jump, docking, saved-source, custody, people, cargo, credits and legal assertion. The returned occupied-crew policy must derive from the original disable incident plus 30 seconds and the actual current clock: occupied/disabled before the deadline, occupied/recovered with positive power after it, and empty/disabled. Preserve the existing empty-hull and duplicate-source checks.

A separate full-stock method uses the untouched `empNativeFlight` scene and one original `disableNativeEMPActor` call, retaining its 800-frame, 0.1-second and real aiming/control budget. Require two actual P80 discharge events, total time covering both warmups and the directly observable second ten-second charge ending at actual zero. The first warmup follows the unchanged production charge gate; its timing is not independently sampled. Require the original actor and ordinary/canonical custody, fatal hull energy, cargo, legal record, original crew, owned hardware, credits and real assault consequences. No full-stock escape claim is made.

After exactly one actual 0.1-second frame with firing released, the original target must remain disabled at zero. Its already-existing owned CrimeLedger attack window must retain its exact last-attack time and not advance past disablement. Require the prior window to exist; an empty attack list cannot satisfy this proof. Use the existing test-only decoder and preserve police/security behavior and the independent source/custody/crew checks.

## Scope and validation

The separate parent is `6dacff5a6b3240b65da9fbb3abf4edddad563b93`. Only `EMPTravelAndSecurityTests.swift` and this new issue/PR pair change: one existing method and one new method, two methods/two cases. Shared flight/travel/roundtrip/aiming helpers, G1's retained-threat decoder and diagnostics, all Security/healthy methods, native UI tests and production remain byte-identical. Preserve the G1 `203ffc2d017b5f9b150ffb5203a9d9972513b5fd` diagnostic ref, the MC1 path leaf and all prior refs.

Only formatting/parsing, strict lint, Markdownlint and static assertion-effect/scope/source/hash/selection checks run here. No compiler, discovery, tests, build, native/UI/media or GitHub jobs run. Root reviews the frozen source before G1 integration/execution; no native pass or certified fatal-hit attribution is claimed. See the [PR handoff](PR-native-emp-persistence-and-full-stock.md).
