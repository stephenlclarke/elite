# fix(flight): re-express work orientations with the actual frame inverse

Work-camera orientation transfer now expresses the old world orientation in the accepted end frame using that represented frame's actual inverse. Canonical model spin uses the same operation when expressing its rotated world basis back into the camera. A small internal `Basis3.workFrameRelative(to:)` helper solves frame coordinates with cross-product cofactors and the determinant of the admitted rotation. It does not normalize or otherwise alter either supplied basis.

This removes the two unintended camera Gram factors from `G R(G W)`, leaving the intended world spin `R W` up to normal arithmetic rounding. The camera pose remains the exact accepted endpoint. No Game state, persisted schema, migration, authority cache, alternate spin, threshold or fallback is introduced. Existing inverse/relative helpers elsewhere are unchanged. The helper's callers operate on admitted work frames and the physical camera rotation; it does not create a general singular-matrix admission path.

`HullSweepSafety`, its outward interval bounds and triangle/dual-mesh computations, `ShipPose` point/vector arithmetic, controller requests, angular integration, work budgets and cutter credit are untouched. The original native test and fixture remain byte-identical. In particular, neither the observer-rebase assertion nor its `1e-8` tolerance changes. Previously saved represented poses are not normalized or rewritten.

## Focused regression and validation

`workFramesPreserveCanonicalSpinWithoutAmplifyingCameraRoundoff` starts with run 542's actual initial camera basis and drives 1,000 real `Game.moveWorkFrame` calls, including the production canonical-spin path, with mathematically admitted empty-scene motion. An independently integrated world spin is the reference. The model axes must match that reference, and the unchanged observer-style point round trip must satisfy `1e-8` for an actual distant point from the retained save. This component test exercises frame consumption; it makes no cutter or native-work admission claim.

`workFrameReexpressionPreservesRetainedBasisWithoutNormalization` uses the actual nonorthogonal parent-derived observer basis from the failing saved stage. Re-expression must restore the represented world axes to `1e-14` without modifying the input frame. The explicit former transpose path must exhibit its larger error. The tests contain no relaxed original assertion or fabricated saved state.

Author validation consists of strict Swift formatting, scoped Markdown lint, whitespace/source correspondence and the retained-data arithmetic replay. No compiler, test, native, debugger or profiling job was run by the author. G1 independently reviews and builds once, then runs these focused regressions and the affected existing accepted-endpoint, canonical-spin and long-frame checks. Their actual results are required before calling the repair validated.

## Timeout remains a separate limitation

The retained first-release generation has physical time 19.28, began work at 3.54, credited the full 16 seconds from its imported 0.25-second baseline and recorded operation 789. It requires 788 admitted 0.02-second cutter increments and at least 964 physical advances. The preserved first-release file mtime is about 265.60 wall seconds after the temporary folder's birth, including simulation, publication and file work; it is not a CPU measurement.

The saved resumed stage is physical time 19.30 with one release and 0.02 seconds of the next cycle. It still needs 799 admitted cutter increments, plus reacquisition and any refused frames. Its actual world contains five bodies; eight pending lots are ledger records and must not be misreported as eight live fragment obstacles. No later clock, loop, hold or work values were recorded with tracing off, so the timeout's remaining stage and cause are unknown. This precision repair is not a measured throughput improvement. Do not rerun a full 600-second acceptance blindly; Root decides that allocation from the focused results and the unresolved scope.

## Retained evidence

The run proof is `/tmp/elite-native-journeys-focused-542/agent-game-test-verification-542.json`, SHA-256 `9029d82bf26e57575e449f3220f71e4d986039691b09d12157e08751ace294b8`. The retained save and provenance are under that run's `retained-save` and `retained-save-provenance.json`. Read-only replay, exact matched errors and per-generation bases are in `/tmp/elite-g2-retained542-roundtrip-analysis.json`; stage bounds are in `/tmp/elite-g2-native542-stage-budget.json`. Run 542 remains unknown without a method terminal. Earlier focused 541 passes and the separate visible-approach repair remain retained; no full CI, sanitizer, leak, Sonar or release acceptance is claimed here.
