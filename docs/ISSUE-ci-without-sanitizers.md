# Remove ASAN and TSAN from required CI

## Motivation

The user requested removal of ASAN and TSAN CI steps. Local sanitizer completion and diagnostic profiling must no longer block the quality workflow or release. Historical incomplete and passing results keep their original scope.

## Required behavior

Remove sanitizer preparation, matrix execution and local-proof requirements from active CI and `make ci`. Keep normal tests, full inventory and coverage checks, zero leaks, static/tooling checks, owned runner authorization, resource monitoring, committed-main SonarQube analysis, PR reviews and required quality outcomes. Manual sanitizer commands remain available.

## Scope and compatibility

Do not modify game code, test assertions, coverage thresholds, leak criteria, saved policies, counters or result files. Existing runner activation still binds the exact source and workflow bytes. Updated native CI needs fresh exact-head authorization and independent normal/leak profiles; old sanitizer bridge activations are not reused.

See [implementation and validation](PR-ci-without-sanitizers.md).
