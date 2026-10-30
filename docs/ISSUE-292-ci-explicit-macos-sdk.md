# Explicit SDK metadata lookup

[Issue 292](https://github.com/stephenlclarke/l337/issues/292) records this prerequisite.

## Problem

PR290 native attempt2 stopped before `make ci`: the default `xcrun --show-sdk-version` query could not locate its selected SDK. The exact-head guard had already accepted the explicit macOS SDK under the intended Xcode developer directory. The default lookup producer is unknown; this does not establish a missing environment variable or a compiler/test failure.

## Required change

Use the same explicit `--sdk macosx` selection for both existing SDK metadata queries. Keep raw output, command exit codes, all-success refusal, separate Swift identities and all execution/resource/security gates.

## Validation and compatibility

Two fake-only regression methods exercise the actual complete metadata block. The original bare commands must fail the broken-default fixture; explicit queries must pass, and either explicit-query failure must retain its error and refuse progression. Native execution, regeneration, leaks and main-only Sonar remain pending. No host configuration change is included.
