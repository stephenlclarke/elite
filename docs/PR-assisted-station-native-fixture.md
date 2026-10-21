# Keep the assisted docking test on its registered station

Use the existing native observer-reframe pattern to reproduce the same tilted station view while preserving its real world anchor and actor. Retain negative spin, exact relative pose and all original docking and switching assertions. After relaunch, retain the newly launched station for the target-switch cohort.

Only this existing AssistanceTests method changes. Shared helpers, other tests, native station state and all docking/physics authority guards stay unchanged. No synthetic dock authority is introduced.

## Validation

MBA formatting, strict lint and whole-file inverse checks pass; copied hashes, ASCII, Markdown lint, diff and exact scope are checked at freeze. No author native execution runs.

G1 owns these existing three methods and three cases:

- stationAutoUsesTiltedEntrancePoseAndSwitchesAwayWithoutResidualTranslation
- stationApproachCompletesForwardAndCollisionFreeForBehindTiltedAndFastStarts: six internal starts, one case
- narrowRefinementRefusesOversizeOrientationWallContactAndStaleAttainedMotion

A complete independent review of the three paths follows actual owner PASS. The captured collision message is evidence of refusal, not a recorded precise guard reason.
