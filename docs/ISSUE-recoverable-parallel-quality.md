# Granular native quality and durable recovery

## Motivation

The required CI quality job executes one opaque `make ci`. A timeout late in that job hides independent phase progress and consumes the same job limit across normal coverage, TSAN, ASAN and leaks. The preserved M01 ASAN group 11 selected 96 IDs and remained incomplete after 9,789 seconds. The current M01 attempt must continue unchanged while the next workflow is prepared.

## Required behavior

- Expose separate build/discovery steps, full normal coverage, each TSAN/ASAN shard, zero leaks and final aggregate in actual required CI.
- Give TSAN and ASAN independent prerequisites, job limits, results and immutable raw uploads. Keep healthy shards running after another failure.
- Retry only missing/failed exact-identity work and retain completed durable proof after timeout/cancellation. Never promote statuses or partial XML.
- Preserve every original `make ci` prerequisite, exact full inventory, opt-in/diagnostic policy, the 80% coverage gate and zero leaks.
- Use useful stable job names and validated completed/total/current summaries. Bound individual executions without pretending that a hard limit checkpoints inside a test.
- Keep whole suites and reviewed shared-process dependencies. Limit packed units without creating hundreds of unnecessary jobs on one physical runner.
- Fail closed without installed exact-head host/event/assignment approval. Keep current M01, branch protections and actual-main requirements intact.

## Bounded implementation

[PR #242](https://github.com/stephenlclarke/elite/pull/242) reuses its reviewed native adapters, durable build/phase/shard proof, private copies, resource admission and trusted artifact transport. The additional CI caller wiring preserves the required job named `quality`; the reusable workflow provides independent mode preparation/shards, normal coverage, leaks, all other prerequisites and strict aggregate/Sonar handling.

The default 64-ID count cap with deterministic count-only planning weights produces 52 shards per mode for the retained 3,403-ID inventory. This is a source-only projection, not a performance measurement. The old 96-ID group contains 20 suites: its three menu cases remain with the complete 170-ID AppKit shared-process cohort; all other suites retain their boundaries. The 13-ID salvage shared-release cohort remains whole. Each native shard has a two-hour execution bound and upload margin. A proven repeated indivisible-cohort timeout stops before another automatic replay and reports the exact decomposition/bound contract that needs review.

The source route supports real CI events, but installation and execution remain G1-owned at a reviewed quiescent boundary. There is one physical runner/private worker and no competing native execution. Old f9/7eb evidence is not promoted across changed workflow/helper inputs. Current M01 is not a dependency of this packet and must not wait for it.

## Installer and timeout follow-up

The legacy installer could install only one guard and listen for one ephemeral job. The explicit reviewed-policy extension now installs all five pinned Python files plus both workflow identities in a separate immutable authorization generation. It supports a single exact-run/attempt serial session with a durable consumed-job budget and finite expiry. Its default legacy behavior remains; active/uncertain ownership and mismatched immutable bytes refuse renewal. Actual installation, credentials, listener lifecycle and activation remain G1-owned and unverified by these fakes.

[Issue #254](https://github.com/stephenlclarke/elite/issues/254) records the independent review finding that an authenticated timeout failure was ignored after cache loss. The correction retains that exact failed timeout proof as a separate sealed blocker, including re-export, without qualifying it as a pass. One focused fresh-store test verifies zero executor calls for the same identity/bound and the changed-bound/identity/ordinary-failure negatives.

## Acceptance and limits

Retain the prior 64 fake-test pass records and review of their unchanged scope. Run only new/affected fake workflow, authorization and recovery cases plus lint, then obtain independent MBA review of the frozen delta. Actual native qualification, copied-build/helper lifecycle, pre-job credentials, job registration lifecycle and throughput remain unverified. No local native run, probe, benchmark, host installation, workflow dispatch or live policy/routing change is part of this packet.

See [the PR handoff](PR-recoverable-parallel-quality.md) for exact file/role ownership, recovery contracts and the concrete G1 installation/required-check transition.

## M01: live progress for both sanitizer modes

The current legacy ASAN group produced a buffered20,480-byte log ending mid-line, while its XML was still a placeholder. Its55 completion lines and57 starts were observations, not a qualified result or a reliable current-test indicator. Stephen requested that G1 stop it cleanly, retain valid completed evidence, and restart through smaller recoverable jobs with useful progress. The same telemetry is required for TSAN. G1 owns stop, ownership qualification, policy and actual operation; this source delta performs none of those actions.

Extend the reviewed `b7c7295f05ef44b4d00fec377354398490e4789e` recovery composition in four paths only: the shared recovery module, its existing fake tests and these paired notes. Keep all production and Swift tests, commands, sanitizer flags, environments, cohort boundaries, timeouts, authorization, importer policy and workflow routing unchanged. The frozen b7 packet and historical9a evidence remain immutable. Raw progress cannot qualify a pass or cross an execution identity.

Capture child stdout/merged stderr through a raw pseudo-terminal without changing stdin, process groups or controlling-terminal behavior. Persist exact raw bytes and observed test-name events, current observed-start ages, elapsed time and periodic flushed heartbeats/summary during silence. Keep concurrent/parameterized names and ambiguous matches explicit. Preserve incomplete lines and interrupted evidence as partial. XML and strict sealed receipts remain the only completion authority. Real Swift flushing remains unqualified until the next required reviewed campaign; no demonstration run or completed-TSAN replay is requested. [Delta and validation](PR-recoverable-parallel-quality.md).
