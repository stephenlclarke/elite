# Issue186: preserve affine time correlation in debris clearance

## Motivation and observed failure

The normal affected-unit batch at `6423e889ab76109f04821e4159fb110be0f9b779` completed all 135 methods, with four failing methods. `nativeMovingDebrisUsesNPCShieldsAndNativeDeathWithoutPlayerReward(targetVelocity:)` still refuses the -3000 case with `REMAINING SWEEP UNPROVEN`. The actual debug record identifies the already impacted debris/NPC pair, with zero angular velocity and acceleration. This is not evidence of a different station or player collision.

`translatedTrianglesClear` encloses the shared time independently in X, Y and Z, then projects the resulting box onto each separating axis. That loses cancellation between coordinate terms driven by the same time. Independent static analysis of the captured motion and actual source triangles found six pairs that the Cartesian enclosure cannot separate, although an affine scalar projection separates all 8,608 pairs. Static floating calculations are not native collision certificates or a passing test.

The candidate retains the position and velocity intervals, projects each onto the same axis first, then multiplies the scalar velocity projection by the one time interval. It keeps outward interval arithmetic, the actual triangles, axes, BVH, numerical clearance, work budgets and all refusal/authority checks. A directed diagonal translation regression checks a thin positive gap, both pair directions and large world offsets.

The correction is under independent source review and remains unqualified until normal execution passes the actual debris case, the new regression and directly affected contact consumers. Three fixture corrections accompany the same focused follow-up. The separate terminal decoder SIGBUS in issue185 remains open and unattributed.

Evidence: `docs/evidence/M01-authored-fixture-unit-results.json`; local normal log and XML under `/tmp/elite-m01-authored-fixtures`. Related PR: [PR25](https://github.com/stephenlclarke/elite/pull/25)

## Compatibility and remaining risks

No contact is admitted from the static calculations. The candidate must pass normal engine execution; otherwise the actual refusal remains. The separate issue185 fault is not resolved by scoped test completion.

## Focused normal follow-up passes

Source `85a69ab6445e0390063638fc26ae2c58a7d7921d` compiled in63.57seconds and passed all40 selected methods in16.846795458seconds (81.655184917seconds overall), with zero failures, errors or skips. This includes both actual debris target-velocity rows, both classic hostility rows, ECM consumption, the real ore-admission timeout, the diagonal regression at zero/large offsets with reversed pairs, and the directly affected contact/fragmentation consumers. The [exact per-method receipt](evidence/M01-affine-followup-unit-results.json) preserves selection and timings. Independent source/result verification is clear. This qualifies the focused correction, not the remaining full quality or release gates. No decoder fault occurred; issue185 remains independent and open.
