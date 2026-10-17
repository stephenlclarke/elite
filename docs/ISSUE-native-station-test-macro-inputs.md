# Native station fixtures mutate value receivers inside assertion macros

Checkpoint 179 failed test-catalogue compilation before `make ci`. Swift Testing captured an immutable receiver while expanding four expressions: refused `Game.fireMissile`, `FlightSimulation.allocateSpawn`, `FlightSimulation.allocateActor` and a second actor allocation in the station-service fixture. No tests or quality stages ran.

## Required behavior

Perform each real mutation once immediately before its original assertion, then assert the returned value. Preserve allocation order, expected flight state, missile refusal, all scenarios and conservation comparisons. Keep Core methods and production guards unchanged.

A bounded scan of nine native RRS/P30 test files identified two additional direct calls to the genuinely mutating `Game.performEquipmentMutation` in assertion arguments. Apply the same single-call separation to their original refusal and applied-result checks. Read-only orientation transforms, enum-case construction, actor-reference calls and throws-block bodies are outside this repair.

## Acceptance

Expanding the local results back into their original assertion arguments must reproduce each complete old test file exactly. Strict source lint and whitespace checks must pass, followed by actual fresh catalogue compilation and the maintained gate. Source formatting is not execution evidence. See [the repair handoff](PR-native-station-test-macro-inputs.md).
