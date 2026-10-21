# Work approach retains inward momentum near an admitted hold point

## Actual failure

The single actual G12 journey in execution1193 failed after121.948seconds with one issue. Its complete first actual failed sweep is retained from /tmp/elite-G12-first-packet-focused-1193/candidate-1193-attempt-01.log, SHA256974e03277d0da355a17bcbd459c0f796cb5b4b6304d0ddeca3f6f53c92dad1d6. Native source was ea8ee5223b546dc4eb77d829f557d9e7bfffc80c. The111544-byte nested packet is complete, with no oversize/encoding refusal. It belongs to the final actual controller clearance reason; a discarded prospective query cannot suppress that candidate's packet.

The first failure is the primary target's endpoint: distanceQueries2 follows the source's start-then-end order and reports clearance137.60255635479686 below unchanged138. Its start equals the previous applied motion's end. After refusal, lastAppliedWorkMotion is nil and unchanged velocity explains the existing unpowered coast. The later final106.90587012874285 gap is not the first failure and does not establish an initially invalid placement or prior motion-application mismatch.

## Captured control mechanism

At that first candidate the position error is4.329090805688255, while relative speed to the rotating work point is21.10491704837247. Error dotted with relative velocity is negative91.35576199358528: the craft is moving away from the requested hold point with residual inward momentum. Captured workPosition agrees with the finite-face-admitted uncompensated baseline to5.7e-14; captured acceleration agrees with the existing workAcceleration +3*(1.5*error-relativeVelocity) law to6.3e-13. These are arithmetic projections of retained fields, without a new hull query or simulation.

In the unsaturated near-hold regime, the existing position response1.5 and velocity response3 give e''+3e'+4.5e=0. Its negative characteristic discriminant permits overshoot even from rest. A one-step exact clearance check correctly refuses the resulting unsafe candidate, but the separately checked brake may already lack enough remaining gap. No clearance waiver, inflated geometric margin or pose adjustment addresses that approach-control mechanism.

## Required correction and acceptance

Retain the existing position response and closing-speed/stopping-distance cap. Derive velocity response as four times position response, making the local linear pair critically damped. Preserve all acceleration, speed, turn, tool-range, exact hull-sweep and independent braking authority. Add stationary non-crossing and rotating finite-hull regressions, preserve all existing test bodies and run the same actual G12 journey on the matching binary after the relevant controller cohort passes.

The linear derivation is not a guarantee for every rotating or saturated trajectory. G1 owns compilation and native qualification, followed by one complete independent bugs/performance/style review before integration. The full G12 journey remains unpassed until actual evidence says otherwise. See [the implementation handoff](PR-critically-damped-work-approach.md).
