# fix(flight): critically damp work approach velocity

## Behavior and implementation

A craft approaching a finite mining surface could retain enough inward relative velocity to overshoot its admitted hold point and lose its clearance corridor. RelativeWorkController keeps the position response1.5 and existing stopping-distance cap, but derives velocity response as4*positionResponse, giving6. The unsaturated local error equation becomes e''+6e'+9e=0, a critically damped pair. Named local gains express that relationship without adding API or configuration.

The same existing acceleration projection and speed limit still bound every request. Facing, target motion, surface selection, finite-face baseline/oblique compensation, tool range, required138 clearance, actual continuous hull validation and separately validated braking remain unchanged. No extra query, geometry, fixture pose, test oracle, cache, framework or diagnostic change is included. Only RelativeWorkController.swift, appended RelativeWorkControllerTests coverage and these paired notes change.

## Regression coverage

relativeWorkStationaryNearHoldConvergesWithoutCrossingItsWorkPoint has three admitted delta cases,0.02/0.05/0.1. From rest twenty units outside its requested hold point, it requires monotonically decreasing signed error without crossing, bounded requests, actual hull admission and final holding. The old underdamped pair crosses that waypoint in this unsaturated regime; this is a behavioral assertion rather than a literal gain check.

relativeWorkRotatingFiniteRockRetainsClearanceWhileApproachMomentumSettles has one case. A closed octahedral target uses the captured G12 target dimensions; a small closed longitudinal player hull has an enclosing radius69 and support near that radius. The finite end surface rotates throughout a real1000-unit approach. Every candidate uses HullSweepSafety with both prepared meshes and the original138 threshold; the test requires approved motion throughout, thirty held frames within the unchanged400x0.05 bound and continued target rotation. This is a small controller boundary fixture, not a replacement for the actual SH023 mining journey.

All existing controller, oblique, finite-wedge300-range and other test bodies remain exact. No old oracle is weakened or replaced.

## Qualification and limits

Author checks are source-only formatting, strict lint, Markdown, diff and exact preservation checks. Native tests are pending with G1. Select the previously qualified1180 relevant controller cohort, unchanged thirteen methods/sixteen cases, plus the two new methods/four cases: fifteen methods/twenty cases. Then run the SAME actualNaturalMiningTwelveOriginalScoopsProcessingAndSeparateReceiverPaysOnce method/one case on that matching binary. G1 owns the exact retained selector list, outcomes and source/binary identity; no author build, native test, debugger, probe or extra diagnostic run occurs.

After actual focused PASS, one complete independent four-path bugs/performance/style review precedes generic correction integration. Normal required CI remains necessary. Critical damping is established for the unsaturated linear regime; full rotating, clamped and actual G12 success must be observed, not inferred from that algebra. See [the captured failure and causal limits](ISSUE-critically-damped-work-approach.md).
