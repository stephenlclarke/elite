# test: use current declared RRS station identities

The shared fixture selects G04-S149 and its matching stored galaxy systems array. It requires one declared source of each station kind and, after real launch, the exact declared identity set under the commander's equipment owner, including an exact count to reject duplicates. Both physical approach kinds and all malformed-save/rollback checks remain unchanged. The same-file main-arrival UUID expectation follows the selected world.

Only `NativeStationIntegrationTests.swift` changes executable code. `StationApproachTests.swift` remains G2's separate scope. No production, default ship/fuel, geometry, native receipt or broader historical population assertions change.

The initial approved proposal needed one additional fixture-context line: `Game.systems` is stored, so changing commander galaxy also selects `Universe.systemsIncludingPlugh(number:)`. Current source rules put both kinds at G04-S149: headquarters index 3 is 149, and the waystation chance 0.42747014109045267 is below Democracy's 0.5 threshold.

Swift formatting and patch whitespace pass. Actual936 matching build PASS and actual939 focused RRS PASS qualify two methods/five cases on composed `c7c4137097d4ecfbdec84db9fe1bd1b645a4a911`. The whole executable test file matches isolated source `a4698c5a440a693afa3b67cd145a09cec1c737b5` byte-for-byte; subsequent changes here are paired notes only. All owner/duplicate/adapter corruption, full live-state/file rollback and both station-kind save/restoration assertions remain intact.

Authoritative outcomes are `/tmp/elite-remaining-fixtures-939/event-stream-qualification.json` and `owner-outcomes.json`; raw log SHA256 is `50f398404a17a4cfb81ef6a9e99889e535fba9a7c61bcff1aef82e41bb68b80a`. G1 closed the entire run with source, preferences and artifacts preserved. Other candidate failures, including the unresolved EMP crash, are separate and are not converted into RRS or overall PASS. Independent review of this test file plus paired notes is pending before G1 acceptance. Canonical ledger remains G1-owned; project PR review and final checks remain required before merge.
