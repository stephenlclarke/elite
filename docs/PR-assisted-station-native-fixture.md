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

## Actual qualification

Matching compilation1256 passes on `3fa2e34da98fc2f8f5cdb80eb472ef1e1c96010c`, including the qualified alias and vertex changes. Actual1257 passes all three selected methods/three cases in58.333seconds (runner62.743153seconds, supervisor65.492965seconds), with zero issues or unknown outcomes. The six internal approach starts remain one declared case. All fifteen observed owned starts close naturally; source, preferences and2010 artifacts remain exact. Raw log SHA256 is `27a52c195e58341ac89920a027d5aece2ff22fd67267008572326427b7ec5f42`; event stream SHA256 is `a0da16dc2af2e1601c3bd2bb0002a4655b685e5377c78e6d256cb23e31f6598e`. Complete independent three-path review is CLEAN (`615e923ccd0cd45f4cf14bc435c697c222cf6b643af247c41b41b0976f03290b`); exact reviewed files integrate at `962cef4c4566b59abc96fa7cccd5f320bfb38a97`. Focused success does not establish hosted or full-suite acceptance.
