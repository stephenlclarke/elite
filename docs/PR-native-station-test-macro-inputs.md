# test(stations): evaluate mutating fixture calls before assertions

The native station test catalogue failed at four mutating receiver expressions inside Swift Testing macros. Those four calls now run exactly once before their existing assertions. The bounded follow-up also separates two direct `Game.performEquipmentMutation` result checks in the same service-test file. See [the compile issue](ISSUE-native-station-test-macro-inputs.md).

## Preservation and validation

Three test files change. The original spawn-then-actor allocation order, actor identities, expected `FlightSimulation`, missile refusal and equipment refusal/applied comparisons remain. Replacing the six new result locals with their original expressions reconstructs the complete previous files exactly. No Core method, allocator, guard, scenario, assertion condition, error protocol, skip or runtime setting changes.

Strict Swift source lint, Markdown lint and whitespace checks pass. The actual pre-fix 179 proof records source `a183c91920b96eda222d8ca4fb31101e9f0e1607`, four immutable-receiver diagnostics and raw log SHA256 `8645fdad9e0f6c6b5f98e4a1ead969e67f47d6cb16bc6d1950292e827069cb73`. It ran no tests or `make ci` stages; protected inputs and owned-process closure were verified. The two additional sites are source-confirmed matching patterns, not additional diagnosed compiler failures.

The repaired catalogue has not been compiled or executed. Fresh discovery, actual focused integration cases and final maintained `make ci` remain required. Actual renderer generation/currentness passed separately at 177 and is not a test result. Completed external review, final-head checks and protected merge remain separate release gates.
