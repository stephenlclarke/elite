# Combined central quality gate: 16 October 2026

The complete maintained `make ci` gate passed on clean committed source `4cf39004374c0d253b955a5150b7b2d5589ddebc`. Its runtime, tests, tools, packages and mission packs are byte-identical to the composed `a23ffc9fa165a26ee2f00d984517423eed55e2be` source. Subsequent evidence documentation does not change the tested commit. The [machine record](CENTRAL-COMBINED-GATE-VALIDATION-026.json) retains the exact inputs, logs, exports and original native artifact hashes.

| Gate | Result |
| --- | --- |
| Maintained prechecks | Passed, including all 168 current ship assets |
| Coverage tests | 840 tests, 56 suites; passed in 62.483 seconds |
| Line coverage | 20,913 of 21,996 lines; 95.08% |
| Full Thread Sanitizer | 840 tests, 56 suites; passed in 343.160 seconds, no findings |
| Serial Address Sanitizer | 840 tests, 56 suites; passed in 745.396 seconds, no findings |
| Leak diagnostics | Zero leaks, zero total leaked bytes |

The complete command exited zero after 1,341.070802667 seconds. All tracked and protected inputs, the production Commander save and private preferences remained unchanged. No further test or build process remained when the lease was released.

Required renderer regeneration preceded the gate: all 168 ships rendered in 42.558664500 seconds; README media generation completed in 11.047435333 seconds. Only source fingerprints in the ship manifest changed. Ship GIFs, README images and icon bytes remained unchanged. The original README scene and a compact native equipment capture were inspected at their original resolutions.

Each coverage, threading and address lane retains 78 original native artifacts: 31 PNG/timing pairs plus 16 additional screen captures. Every paired fixture records the exact tested source and passes byte parity. Same-fixture native/oracle timing ratios range from 0.2943 to 1.3192 across the three lanes. The additional 16 images per lane are preserved screen captures, without parity timing records. These results do not establish physical trackpad hardware or display scanout behavior.

The affected focus is deliberately reported as separate evidence: 45 individual passes from the failed 025 aggregate were retained with unchanged-source proof, then the two corrected inventory display methods passed fresh in 026. The [focused record](CENTRAL-COMBINED-FOCUSED-VALIDATION-026.json) retains both runs. The original 025 failure and earlier failed checkpoints remain failed historical evidence. No guard, test failure, timeout or timing result was waived.

Passing CI does not close the independent whole-app review. The preliminary handoff recorded 18 findings; the final qualification is 17 confirmed findings (two P1, 13 P2 and two P3) plus one separately labelled investigation candidate. The two P1 findings concern Save/Open ordering and validation before mission-payload arithmetic. The original unlimited-new-deaths claim was retracted because the NPC ledger caps terminal/logical entries at 128. A revised living-NPC cull/rebind growth route is source-traced but remains unconfirmed pending a repeated lifecycle regression. The machine record retains the preliminary counts as historical evidence and adds this final qualification. No review fix entered the frozen gate. Formal PR review, remediation, accepted mission-engine composition, main-branch SonarQube publication and release remain separate outstanding work. This is a validated central checkpoint, not merge or release approval.
