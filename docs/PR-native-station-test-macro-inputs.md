# test(stations): evaluate mutating fixture calls before assertions

The native station test catalogue failed at four mutating receiver expressions inside Swift Testing macros. Those four calls now run exactly once before their existing assertions. The bounded follow-up also separates two direct `Game.performEquipmentMutation` result checks in the same service-test file. See [the compile issue](ISSUE-native-station-test-macro-inputs.md).

## Preservation and validation

Three test files change. The original spawn-then-actor allocation order, actor identities, expected `FlightSimulation`, missile refusal and equipment refusal/applied comparisons remain. Replacing the six new result locals with their original expressions reconstructs the complete previous files exactly. No Core method, allocator, guard, scenario, assertion condition, error protocol, skip or runtime setting changes.

Strict Swift source lint, Markdown lint and whitespace checks pass. The actual pre-fix 179 proof records source `a183c91920b96eda222d8ca4fb31101e9f0e1607`, four immutable-receiver diagnostics and raw log SHA256 `8645fdad9e0f6c6b5f98e4a1ead969e67f47d6cb16bc6d1950292e827069cb73`. It ran no tests or `make ci` stages; protected inputs and owned-process closure were verified. The two additional sites are source-confirmed matching patterns, not additional diagnosed compiler failures.

The repaired catalogue has not been compiled or executed. Fresh discovery, actual focused integration cases and final maintained `make ci` remain required. Actual renderer generation/currentness passed separately at 177 and is not a test result. Completed external review, final-head checks and protected merge remain separate release gates.

## Checkpoint 181 fixture clock follow-up

The next actual catalogue compile reported one overlapping Commander borrow in `NativeStationPersistenceTests`: assigning `currentMainDock` while reading `scriptState.calendarSeconds`. The main-case fixture now reads that primitive value immediately after the original dock call and before assigning the same receipt. Expanding the clock local reconstructs the complete previous test file exactly. All original custody, negative-save, state and file comparisons remain; no Core or calendar policy changes.

The bounded nine-file scan used actual current canonical source `ac411136d974e5f46b847ec0c802ec9d0d0de3da`, found only this identical remaining pattern and confirmed the raw fixture already carried its separate clock repair. Actual 181 failed before tests or `make ci`; raw log SHA256 `f593a67a200a2b14dd99a8f492770108a3ba31a74e9e4b738bff32031ff691b6`. Strict source/Markdown lint and whitespace checks pass. The corrected catalogue still requires compilation and execution.
