# Preserve the completed M01 normal run after a generated profile blocked qualification

## Problem

PR 232's native run completed all 3,403 declared normal test outcomes and measured 90.47633943583769% coverage. Its aggregate job then failed because LLVM left a root `default.profraw`, which the final clean-checkout guard correctly rejected. Thread sanitizer, address sanitizer and leak phases were not reached. The original attempt, reports, profile and exact executable are preserved; the aggregate result remains failed.

## Required behavior

Ignore only the root fallback profile. Continue rejecting modified tracked source, untracked maintained source and nested profiles. Retain the complete execution identity and immutable original receipt. A single, host-authorized M01 attestation may qualify that specific prior normal execution after the independently reviewed bookkeeping-only changes. It must identify the old tested revision and current qualified revision separately, prove every runtime/dependency/selection/toolchain/image/output predicate, enumerate exact reviewed non-runtime blob changes and reject every unlisted difference. Other quality phases remain mandatory.

## Scope and verification

The change is limited to the anchored ignore rule, fake-process/real-Git regressions, one M01-specific validator and its normal-phase consumption hook. It changes no Swift source, ship data, runtime state, test selection, coverage threshold or general cache-identity rule. Positive and negative fake cases must pass, followed by independent review of one frozen packet before installation of the immutable host authorization. The saved normal execution is not rerun or relabelled as execution of the new source.
