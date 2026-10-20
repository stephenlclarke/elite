# test: separate post-pulse EMP assertion lifetime

The full-stock Cobra test calls its unchanged native 800-frame helper, then a private `@inline(never)` verification phase containing the byte-exact original assertion tail and final tick. This delays the post-pulse temporary workspace until native simulation returns. It targets the measured large caller frame; improvement is unmeasured until a matching build runs.

The original setup and helper call are byte-identical. All 70 `#require` calls, one native-helper call and one final `game.tick` remain in the method plus its verification phase, in the original order. `EMPReleaseBoundaryFixture.swift` is unchanged. No production implementation, fixture expectations, timing, weapon, shield, energy, ship, fuel, stack or concurrency settings change.

Validation: source conservation and patch whitespace checked. Build and test are UNRUN under Root's source-only freeze. G1 first runs `EliteCoreTests.EMPTravelAndSecurityTests/fullStockNativeCobraRequiresTwoRealPulsesAndCannotAttackAfterElectricalZero()` on the matching shared candidate with original default worker stack and original helper bound. Independent review, required CI and final-head PR review/checks remain open. This packet is validation pending, not integration ready or a release claim.

Linked assignment: M01 through Orchestrator. Risk: a smaller caller workspace may still be insufficient; actual focused execution must establish the result.
