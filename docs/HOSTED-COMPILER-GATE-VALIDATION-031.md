# Hosted compiler repair local validation: 16 October 2026

The full maintained `make ci` gate passed on exact committed source `277f4c62a6b5509adc8922c8b30b519f702fa28f`, containing the reviewed actor-snapshot compiler decomposition. Its runtime matches `0d2d0dc4038a862616b6a688e46532163c8a55a0`; subsequent changes before the freeze are evidence documentation and renderer fingerprints. The [machine record](HOSTED-COMPILER-GATE-VALIDATION-031.json) preserves exact inputs, logs, exports and original native artifact hashes.

| Gate | Result |
| --- | --- |
| Maintained prechecks | Passed, including all 168 current ship assets |
| Coverage tests | 897 tests in 69 suites; passed in 65.954 seconds |
| Maintained line coverage | 21,427 of 22,524 lines; 95.13% |
| Full Thread Sanitizer | 897 tests in 69 suites; passed in 353.262 seconds, no findings |
| Serial Address Sanitizer | 897 tests in 69 suites; passed in 788.733 seconds, no findings |
| Leak diagnostics | Zero leaks, zero leaked bytes |

The full command exited zero after 1,363.362002750 seconds. All tracked and protected inputs, the production Commander save and private preferences remained unchanged. No owned heavy process remained when G1 explicitly released lease 031.

The actual hosted failure remains failed historical evidence: [run 38927024481](https://github.com/stephenlclarke/elite/actions/runs/38927024481) on `f82953b920de06461a017c7aad2644ec65857410` failed before tests because the compiler could not type-check the large actor-snapshot expression within its limit. The correction introduces typed intermediate facts without changing value precedence, defaults, units or identities. It changes no compiler limit, test or quality threshold.

Before the full gate, the maintained mission-pack producer passed in 5.609444500 seconds and the actual selected set of 45 methods in four suites passed in 9.147 seconds (command 25.605837959 seconds). The [focused evidence](HOSTED-COMPILER-FOCUSED-VALIDATION-031.json) retains exact source and selection parity. Required renderer generation completed for 168 ships in 43.779136625 seconds; README media completed in 11.369226625 seconds. Only source fingerprints changed; all ship GIF, README media and icon bytes remained unchanged. Original flight and compact native inventory captures were inspected.

Each coverage, threading and address lane retains 78 original native artifacts, including 31 PNG/timing pairs and 16 additional untimed captures. All 93 paired fixtures name the exact tested source and pass byte parity. Same-fixture native/oracle ratios range from 0.704866 to 1.894267, with no timeout or order-of-magnitude slowdown. Physical trackpad hardware and display scanout remain outside these checks.

This is local Apple Swift 6.4 validation. Fresh final-head hosted compilation and CI remain necessary, as does a clean requested public review. An automated reviewer unknown error is not approval. The separately isolated canonical mission composition, main-only exact-SHA SonarQube analysis and release remain outstanding. Earlier failed logs and input maps remain preserved; no failure, guard or timing was waived.
