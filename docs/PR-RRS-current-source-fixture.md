# test: use current declared RRS station identities

The shared fixture selects G04-S149 and its matching stored galaxy systems array. It requires one declared source of each station kind and, after real launch, the exact declared identity set under the commander's equipment owner, including an exact count to reject duplicates. Both physical approach kinds and all malformed-save/rollback checks remain unchanged. The same-file main-arrival UUID expectation follows the selected world.

Only `NativeStationIntegrationTests.swift` changes executable code. `StationApproachTests.swift` remains G2's separate scope. No production, default ship/fuel, geometry, native receipt or broader historical population assertions change.

The initial approved proposal needed one additional fixture-context line: `Game.systems` is stored, so changing commander galaxy also selects `Universe.systemsIncludingPlugh(number:)`. Current source rules put both kinds at G04-S149: headquarters index 3 is 149, and the waystation chance 0.42747014109045267 is below Democracy's 0.5 threshold.

Swift formatting and patch whitespace are checked. Focused tests are UNRUN, with no runtime or integration-readiness claim. First qualification should run the three malformed-save reasons and both docked-save station kinds on a matching build, then the directly affected shared-fixture consumers under Root's finite execution grant. Independent review precedes G1 integration; project PR review and final checks remain required before merge.
