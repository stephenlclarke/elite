# Keep the Crimbo actor entry fixture's rotating station synchronized

## Observed failure and source cause

Run 318 passed the other actor cases and the cohort restoration regressions, but the refused RRS entry case retained the launch message and produced an attained-motion fact. The fixture had not established an actual native entry attempt.

Its station helper advanced only `flightSimulation.physicalTime` from zero to 0.1 seconds, then advanced the convoy adapter. The rotating RRS body remained at its old model phase. `detectNativeStationEntry` first requires `bodyRigidPoseIsConsistent`: the saved pose expects `physicalTime * rotationRate`, with a `1e-5` vector tolerance. At the waystation's 0.02 radian/second rate the fixture creates a 0.002-radian phase gap. A later real tick advances both clocks by the same duration, retaining that gap and causing the entry predicate to skip the body.

## Required fixture correction

Prepare the scene with an actual native tick so station model rotation, physical time and convoy movement advance together. Keep the actual `GameRuntime.advance` doorway test and its save-location refusal/motion-discard assertions. Require the authentic rigid pose before approach and verify the player crosses from positive doorway depth into the tunnel. No pending proof injection, entry predicate relaxation or production callback change is needed.

## Validation boundary

Only the actor station helper, refused-entry method and this issue/PR pair change. The shared main-contact test keeps its assertions and uses the corrected physical setup. G1 owns actual execution of the failed entry and affected contact scopes. See [implementation handoff](PR-native-crimbo-entry-fixture.md); source checks are not runtime acceptance.
