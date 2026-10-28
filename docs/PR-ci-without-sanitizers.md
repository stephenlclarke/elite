# CI without mandatory sanitizers

## Result

The active quality workflow runs actual `make ci` after hosted fake checks and exact native authorization. ASAN and TSAN preparation, shards, local proof verification and sanitizer-plan aggregate jobs are removed. The required final result checks actual authorization, fake checks and native execution; failed, cancelled or skipped work cannot become a pass. Main-only SonarQube follows successful native checks and retains the exact committed-main SHA rule.

`make ci` keeps normal coverage, zero leaks and existing static/tooling checks. The manual `threads`, `threads-full` and `address` targets remain available. Historical sanitizer evidence, policies, counters and diagnostic code are preserved. [Request and constraints](ISSUE-ci-without-sanitizers.md).

## Resource and identity preservation

Normal/leak profiles no longer depend on a local sanitizer proof descriptor. They remain separately reviewed and mandatory for active native CI. Missing, partial or malformed profiles refuse execution. One existing owned monitor covers each complete fresh phase helper, including build, discovery, tests, metadata and postprocessing. The child retains the shared executor lease and unchanged command streams. Its exact live wrapper PID, start identity, Python executable, physical helper source, phase and command are checked before execution. Normal phases still require observed test helpers. No game sources, Swift assertions, coverage thresholds or leak criteria change.

New maintained source and workflow bytes require new exact-head native authorization. Existing deny hooks and historical operator state are not rewritten by this source change.

## Validation

Thirty-eight focused Python tests pass, covering workflow outcomes, normal/leak profiles without local sanitizer proofs, profile refusals, monitoring, retained manual tools and relevant authorization regressions. Actionlint passes for both active quality workflows. `make -n ci` contains normal and leak execution and no ASAN/TSAN invocation. Whitespace checks pass. No native build, Swift test, sanitizer, leak probe or Sonar publication ran for this CI configuration change.

A broader 230-test Python run exposed pre-existing diagnostic fixture drift (missing fake custody/lease setup) as well as old workflow assertions. The affected workflow assertions and selected fixtures were corrected; the broader run is not reported as passing. Full CI/native results and final-head PR review remain outstanding.
