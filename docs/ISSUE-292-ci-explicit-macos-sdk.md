# Explicit SDK metadata lookup

[Issue 292](https://github.com/stephenlclarke/l337/issues/292) records this prerequisite.

## Problem

PR290 native attempt2 stopped before `make ci`: the default `xcrun --show-sdk-version` query could not locate its selected SDK. The exact-head guard had already accepted the explicit macOS SDK under the intended Xcode developer directory. The default lookup producer is unknown; this does not establish a missing environment variable or a compiler/test failure.

## Required change

Use the same explicit `--sdk macosx` selection for both existing SDK metadata queries. Keep raw output, command exit codes, all-success refusal, separate Swift identities and all execution/resource/security gates.

## Validation and compatibility

Two fake-only regression methods exercise the actual complete metadata block. The original bare commands must fail the broken-default fixture; explicit queries must pass, and either explicit-query failure must retain its error and refuse progression. Native execution, regeneration, leaks and main-only Sonar remain pending. No host configuration change is included.

## Coherent downstream identity follow-up

Before push, source inspection found five further implicit SDK identity queries in the required normal/leak helper and existing recovery/optional sanitizer helpers. The successor changes only their argument lists to the same explicit macOS selector. It preserves each identity field, Swift output, profile/flags, validation, execution lease and resource budget. Optional sanitizers remain off; only fake fixtures exercise their existing identity path. The first81b correction and its62 passing fake tests remain scoped evidence.

Two new fully mocked normal/leak methods test persisted SDK version/path selection and refusal of either explicit query failure; existing recovery runtime and two sanitizer boundary fixtures reject broken default lookups and assert recorded SDK identities. These successor changes/tests are prepared UNRUN. No actual downstream failure, SDK regeneration, native test or leak result is claimed from source inspection. Source review precedes fake execution and coherent committed review/protected checks.

## Coherent fake validation result

The original five bare identity queries failed the focused five-method cohort with four assertion failures and five expected SDK lookup errors; corrected queries passed all five methods. `make sanitizer-checkpoints-check` passed32 sanitizer-checkpoint fixtures,20 normal/leak checkpoint fixtures and7 normal-attestation fixtures. The existing recovery suite passed153 tests. These212 tests are entirely fake/filesystem checks; the unchanged earlier capture suite's62 passes remain scoped evidence. Actual results and full logs are retained at `/tmp/l337-explicit-sdk-coherent-validation/results.json`, SHA25654e184fe8a2a05c72510562ee357ab825ab33fd9a16399cc077474f43ba1bb55. Native regeneration, coverage, real leaks, main-only Sonar and protected integration remain pending.
