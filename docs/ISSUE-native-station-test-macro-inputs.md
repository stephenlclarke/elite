# Native station fixtures mutate value receivers inside assertion macros

Checkpoint 179 failed test-catalogue compilation before `make ci`. Swift Testing captured an immutable receiver while expanding four expressions: refused `Game.fireMissile`, `FlightSimulation.allocateSpawn`, `FlightSimulation.allocateActor` and a second actor allocation in the station-service fixture. No tests or quality stages ran.

## Required behavior

Perform each real mutation once immediately before its original assertion, then assert the returned value. Preserve allocation order, expected flight state, missile refusal, all scenarios and conservation comparisons. Keep Core methods and production guards unchanged.

A bounded scan of nine native RRS/P30 test files identified two additional direct calls to the genuinely mutating `Game.performEquipmentMutation` in assertion arguments. Apply the same single-call separation to their original refusal and applied-result checks. Read-only orientation transforms, enum-case construction, actor-reference calls and throws-block bodies are outside this repair.

## Acceptance

Expanding the local results back into their original assertion arguments must reproduce each complete old test file exactly. Strict source lint and whitespace checks must pass, followed by actual fresh catalogue compilation and the maintained gate. Source formatting is not execution evidence. See [the repair handoff](PR-native-station-test-macro-inputs.md).

## Separate fixture borrow follow-up

Checkpoint 181 then diagnosed an overlapping Commander borrow in the unproved-main-dock save fixture: its station-receipt assignment read the same commander's calendar. Read that primitive clock immediately before the assignment, inside the same main case after the same dock call, preserving receipt contents and every refusal/conservation assertion. A bounded scan of the nine current native RRS/P30 files found this one remaining identical pattern; the separate raw-save fixture had already received its equivalent repair.

Checkpoint 182 diagnosed the corresponding optional equipment-owner read inside a nested station-ledger mutation in `NativeStationServiceTests`. Snapshot that same optional value immediately after docking and pass it unchanged; adding a required-owner guard would alter the negative fixture and is outside the repair.
