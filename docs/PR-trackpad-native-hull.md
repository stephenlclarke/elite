# fix(test): select native Cobra for trackpad runtime witnesses

Only the failing trackpad runtime method now selects SH023 before launch, initializes fuel through its actual fuelCapacity, initializes native energy/front/rear shields and requires a valid Commander. The method becomes async throws for that prerequisite. It retains the exact original launch-to-final-stop body, including gesture positions,100/10frame loops,0.1deltas,32/20/.4literals, body movement, release stabilization and final zero-speed assertions.

No production file, shared fixture helper, input policy, native hull parameter or other failing fixture changes. Game, NativeStationInertia and AsteroidDebrisContact remain under their existing owner's scope. This is a local stale-premise correction; it does not establish a native input repair, project-wide pass or release completion.

## Qualification

The matching owner selection is four nonparameterized methods/four cases:

- trackpadHoldsTurnOrThrustEveryFrameAndReleaseStabilizesAtCruisingSpeed
- heldTrackpadDirectionUsesAbsolutePositionAndNeutralCenter
- trackpadFingerCountSelectsBrakingSteeringAndAcceleration
- trackpadRejectsSystemGesturesAndInvalidContactsUntilLift

Source parse/format/strict lint, original runtime-tail/existing-method preservation, paired Markdown and diff checks pass. Native compilation and selected execution are pending with G1, the sole executor/integrator. No author native job, probe or full review runs. Real compiler/unit corrections come first, then one independent bugs/performance/style review of the passing freeze before integration and normal required CI. See [the three actual failures and native calibration](ISSUE-trackpad-native-hull.md).
