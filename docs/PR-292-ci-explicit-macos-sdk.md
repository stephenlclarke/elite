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
