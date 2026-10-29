# Recover completed quality phases and sanitizer groups

## Problem and resulting behavior

When a later quality step fails, rerunning `make ci` reuses only complete successes for the same executable inputs, dependency content, actual image hash/UUID, toolchain/SDK, architecture/OS, relevant environment, complete selection and policy. Failed, interrupted, incomplete, changed or tampered evidence never qualifies. The tested and current commit identities remain explicit; a documentation-only commit may reuse identical executable evidence, while runtime changes cannot.

## Implementation

`sanitizer_checkpoints.py` keeps the existing durable attempt format and global executor lock. ASAN keeps nonparallel whole-suite batches. Default TSAN packs whole suites around a soft 100-method target with normal internal concurrency; the reviewed AppKit and salvage shared-state groups are indivisible. The source-hashed membership manifest is fail-closed. All discovered methods appear exactly once; no silent omission, synthetic success, arbitrary skip allowance or cross-mode reuse is introduced. Existing exact inactive opt-in handling is retained.

`make threads-full` runs the separately labelled original full-concurrent TSAN selection. It is callable but not an additional mandatory step in `make ci`. Arbitrary overlap across default TSAN groups is different coverage. The original full-mode attestations remain historical proof; the new schema does not promote or requalify them.

`quality_phase_checkpoints.py` uses the same lock and durable cache root for normal/coverage and leak phases. It performs the incremental build and identifies the actual image before checking reuse. Normal execution retains complete Swift Testing XML, raw log, profile, LCOV and generic coverage, with the original 80 percent coverage gate. Leak execution retains the original `leaks --atExit -- <image> --diagnostics` command and requires successful exit plus an explicit zero-leak report. Successful resumed phases restore derived coverage/leak outputs. Static checks still execute freshly, and aggregate success still requires every Make prerequisite.

Build wall, native process wall, postprocessing wall and reused original wall are reported separately. Original native exit codes remain distinct from coverage-tool and evidence-validation failures. Failed attempts retain their terminal reason. Derived artifact copies remain writable for checkout cleanup; cached original evidence stays immutable. Relevant environment values are identity hashes, avoiding raw secret values in receipts.

The first-fault observer retains its original legacy normal-helper eligibility. One narrowly scoped variant recognizes the exact checkpoint normal helper arguments and an owned physical default-cache phase attempt. Filters, sanitizer flags, foreign images/reports, traversal and symlinked evidence remain ineligible. Saved Swift 6.4.1 sanitizer helper evidence establishes that `--skip-build` and rewritten `tests-swift-testing.xml` arguments reach the helper; the new normal variant itself has not been executed natively. Custom cache roots do not gain this additional observer eligibility.

## Resume procedure

1. Preserve the failed attempt and let any owned native helper terminate naturally or through the existing owned cleanup policy. A live helper blocks replacement.
2. Rerun `make ci` from a clean committed checkout. Completed phases/groups with exact current identities are verified and copied into the new report; the failed or missing group executes again.
3. Inspect `reports/quality-phases/<phase>/` and `reports/sanitizers/<mode>/` for explicit executed/reused status, original tested commit, current commit, selection and timing. A phase success is not an aggregate success.
4. Keep the normal final-head review, coverage, sanitizer, leak, committed-main SonarQube and release requirements. This change does not publish a release or alter live runner settings.

## Validation

Focused Python fake-process tests cover exact selection, suite/shared-group preservation, retained concurrency flags, later-group/phase failure and resume, source/image/environment/policy drift, missing or tampered evidence, leak/coverage refusal, command ownership and failure/timing records. These tests execute no Swift test body, native build, UI or profiling command. Independent source review must be clear before handoff. Exact results are recorded in the accompanying authoring receipt; native qualification is pending.

## Compatibility and remaining risks

The default TSAN process topology changes, explicitly approved for recovery. The audited process-sharing manifest does not prove comprehensive cross-suite equivalence. Source changes to audited participants require manifest review; oversized groups remain intact and can take longer than the soft target suggests. Reuse still needs an identical rebuilt image, so path/toolchain changes may correctly require fresh execution. No wall-time savings are claimed before native measurement.

Related: [issue handoff](ISSUE-recoverable-quality-phases.md), [PR25](https://github.com/stephenlclarke/elite/pull/25). Integration belongs to the sole executor after the live run terminates and its exact evidence is retained.
