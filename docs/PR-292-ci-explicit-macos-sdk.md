# fix(ci): select macOS SDK explicitly for quality metadata

Closes [Issue 292](https://github.com/stephenlclarke/l337/issues/292).

## Motivation

The quality capture used an implicit SDK lookup while the existing exact-head guard selects macOS explicitly. On PR290 attempt2 the former failed before any compiler or test phase. The failed run and its historical reports remain preserved and separate.

## Implementation

Add `--sdk macosx` to the two existing path/version metadata commands only. Add two fake-only regressions to the existing crash-artifact test target; extract the unique, structurally pinned complete maintained metadata block, including its original failure assertion. No hosted script import, compiler, SDK probe, workflow or environment change occurs in these tests.

## Validation

The original bare commands failed all three regression cases as intended. The corrected two methods passed, and `make ci-capture-check` passed all62 tests (0.136 seconds framework/0.37485 seconds wall). The first fixture omitted the metadata print block's source-head value and errored in both source states; that failure remains preserved and is not regression proof. Adding only a fixture head value produced the meaningful comparison. Immutable logs/results are retained under `/tmp/l337-explicit-sdk-metadata-validation-v2`, results SHA256935507b6773ef64c444200f23abca56b7086507a41663389687b7a4f1c656922. Independent final source/result review, required native checks and protected merge remain pending. Compiler versions remain distinct recorded observations.

## Compatibility and risks

Use the macOS SDK already required by the native guard. Explicit lookup failures still retain raw metadata and stop quality capture. This correction does not prove SDK module regeneration, passing tests, zero leaks or release readiness.

## Coherent downstream identity follow-up

Before push, source inspection found five further implicit SDK identity queries in the required normal/leak helper and existing recovery/optional sanitizer helpers. The successor changes only their argument lists to the same explicit macOS selector. It preserves each identity field, Swift output, profile/flags, validation, execution lease and resource budget. Optional sanitizers remain off; only fake fixtures exercise their existing identity path. The first81b correction and its62 passing fake tests remain scoped evidence.

Two new fully mocked normal/leak methods test persisted SDK version/path selection and refusal of either explicit query failure; existing recovery runtime and two sanitizer boundary fixtures reject broken default lookups and assert recorded SDK identities. These successor changes/tests are prepared UNRUN. No actual downstream failure, SDK regeneration, native test or leak result is claimed from source inspection. Source review precedes fake execution and coherent committed review/protected checks.

## Coherent fake validation result

The original five bare identity queries failed the focused five-method cohort with four assertion failures and five expected SDK lookup errors; corrected queries passed all five methods. `make sanitizer-checkpoints-check` passed32 sanitizer-checkpoint fixtures,20 normal/leak checkpoint fixtures and7 normal-attestation fixtures. The existing recovery suite passed153 tests. These212 tests are entirely fake/filesystem checks; the unchanged earlier capture suite's62 passes remain scoped evidence. Actual results and full logs are retained at `/tmp/l337-explicit-sdk-coherent-validation/results.json`, SHA25654e184fe8a2a05c72510562ee357ab825ab33fd9a16399cc077474f43ba1bb55. Native regeneration, coverage, real leaks, main-only Sonar and protected integration remain pending.
