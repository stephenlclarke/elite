# Native window fixture full validation: 16 October 2026

The maintained `make ci` gate passed on exact committed source `d29d64bc0cdeda934e352d4f9fb1ad7167c374e3`. Runtime and tests match reviewed native window correction `9b8e76e833a9e1755a28b34ee2f41a7e2dce8f5d`; qualified focus documentation was completed before the source freeze. The [machine record](NATIVE-WINDOW-GATE-VALIDATION-036.json) retains original logs, hashes, exports, protected inputs and independent verification.

| Gate | Result |
| --- | --- |
| Maintained prechecks | Passed, including all 168 current ship assets |
| Coverage tests | 898 tests in 69 suites; passed in 66.346 seconds |
| Maintained line coverage | 21,438 of 22,528 lines; 95.16% |
| Thread Sanitizer | 898 tests in 69 suites; passed in 343.805 seconds, no findings |
| Serial Address Sanitizer | 898 tests in 69 suites; passed in 800.517 seconds, no findings |
| Leak diagnostic | Process 60058: zero leaks, zero leaked bytes |

The full command exited zero after 1,383.136704666 seconds. All tracked and protected inputs, the production Commander save and private preferences remained unchanged. The coordinator independently verified the results and released slot 036 with no remaining heavy process. No failed attempt, assertion or quality gate was waived.

Each coverage, threading and address lane retains 79 original native artifacts, including 31 exact-source PNG/timing pairs and an actual window geometry receipt. All 93 paired fixtures pass byte parity. Same-fixture native/oracle ratios range from 0.399472 to 1.444872, with no timeout or order-of-magnitude slowdown. Shop and flight originals from the [36-test focused run](PR-hosted-native-window.md) were inspected before the full gate. Production window construction and screen-fitting remain unchanged; only the two fixtures inject the test window. The actual hosted screen geometry remains unknown until a new hosted run records it.

This is local Apple Swift 6.4 validation. The previous hosted run used Apple Swift 6.1.2 and failed on native height assertions; it remains [failed historical evidence](ISSUE-hosted-native-window.md). Final-head hosted full CI and an actual clean requested review are still required before merge. Reviewer service errors do not count as approval. Main-only exact-SHA SonarQube analysis, release and the separate canonical mission composition remain outstanding.
