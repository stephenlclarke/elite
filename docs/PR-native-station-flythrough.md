# Observe native station geometry during the reported fly-through

## Result

Opt-in native frame profiling now records explicit window, docked, paused, camera, energy, shield and message state, including the state at a refused frame. The original combined guard is split into the same two required conditions with distinct failure reasons. A read-only Core projection returns the actual bound station identity, rendered and canonical poses, source mesh counts/bounds, center range, effective player radius and the same conservative sweep result used by native station collision handling.

An additional `--profile-station-geometry` option captures at most three actual AppKit renderer views for approach, close pass and failed clearance, each with its corresponding sample JSON. Capture draws remain identified and excluded from distinct-draw statistics. The production loop, normal commander, seed, original +Z heading, three-finger throttle, collision behavior, guarded active window, warm-up, trajectory and time budgets are unchanged. This diagnostic does not fix or dismiss the reported visual defect.

## Validation

Source parsing, strict formatting, scoped Markdown lint and whitespace checks precede source handoff. Two focused tests check actual bound source geometry, read-only behavior, unresolved time and refusal of a stale physical binding. Compilation, test execution and the enhanced native capture are pending the sole validation lease. The prior 309 compact protocol result is not native visual acceptance; fullscreen remains incomplete.

## Compatibility and remaining risk

The projection confers no gameplay, docking or collection authority. It performs extra opt-in diagnostic work, so compare performance only with the same instrumentation. A failed conservative sweep is a refused-clearance observation, not an exact penetration depth. Inspect the images and actual state before implementing the geometry or motion repair, then run the relevant regressions and native validation. No full CI, coverage, leak, clean GitHub review or release claim is made here.

## Link

[ISSUE-native-station-flythrough.md](ISSUE-native-station-flythrough.md).
