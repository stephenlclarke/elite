# PR #242: recoverable parallel quality execution (HELD)

## Problem and result

Serial sanitizer batches make independent retry and bounded parallel execution difficult. [PR #242](https://github.com/stephenlclarke/elite/pull/242) implements stable whole-unit planning, durable immutable proofs, native preparation/execution, owned process tracking, trusted artifact restoration and independent GitHub jobs. Physical execution is disabled in code and defaults off in the manual workflow. Source/fake validation does not establish native quality or throughput.

The original five reserved files contain the new protocol, tests, workflow and paired documentation. The separately reserved `Tools/CI/native_runner.py` and `test_native_runner.py` extend host authorization; existing CI-only behavior remains the default. Existing sanitizer/coverage/leak helpers, `ci.yml`, Makefile, branch protections, routing variables and active M01 state are unchanged.

## Planning and identity

`recoverable_shards.py plan --input request.json --output plan.json` accepts frozen runtime facts and discovered inventory. Optional history is a positive duration hint keyed by the sorted atomic selection hash; the deterministic fallback uses whole-suite size. Targets are 300-600 seconds. Both local and GitHub queues order long units first. Oversized suites/groups remain intact. The actual AppKit 170/32 and salvage 13/2 source manifests are audited for both sanitizer modes; internal TSAN concurrency and ASAN `--no-parallel` are preserved.

A shard ID binds exact methods, atomic membership, selected source-bound resource audits, mode and actual runtime facts. Runtime fields bind maintained executable inputs and dependency sources, compiler, SDK version/path, hardware UUID, OS, architecture, image hash/UUID, actual relevant child controls and protocol. It excludes ordinals, time estimates and worker assignment. Timing/configuration changes alone do not change an unchanged shard ID. Changes to maintained Tools/workflow source bytes remain real executable-input changes and invalidate prior proofs. Native approval controls are retained, so their actual changes can also invalidate reuse.

The shared execution-policy digest covers protocol, host and static admission bounds. Planning hints and placement are outside that digest; each selected resource audit stays in its own shard identity. Resource independence is an explicit reviewed declaration with current source hashes and file/preferences/port/save-path claims. Existing shared-process grouping alone does not prove external independence. Unknown groups exclude all external consumers; conflicting claims serialize.

This is a new schema-1 protocol with policy `recoverable-parallel-shards-v1`. Old schema-3/packing-index receipts are not promoted.

## Native preparation and observed execution

`NativeAuthority` fails at the disabled code guard before policy inspection or probes. After separate activation it requires the existing physical-host checks, a clean approved controller, host-owned policy, exact checkout/workflow bytes and nonoverlapping durable/private paths. One shared host-owned policy names exact runner instances and canonical workspaces. Relevant parent controls must agree across instances; no general path or environment normalization is used.

`NativeBuilder` takes the actual legacy executor lock exclusively and the new preparation lock before using the existing build/discovery helper once per mode. It captures the complete scratch layout, resources, dependency data, relative internal links, executable bits and hashes into an atomic fsynced sealed mode bundle. Committed orphan stages can be rescanned. Private clone/scratch copies are restored from that bundle and reused under exclusive workspace locks. Missing known bundles or tampered data fail closed; authenticated portable build artifacts can restore them without another compilation. There is no hardlink alias to a writable controller build, and no source copy for each test shard.

The prepared image path is relative, canonical and contained in its mode scratch. Workers recheck tracked controller blobs, private inputs, actual image, UUID, compiler, SDK, OS, host and controls before and after running the existing skip-build command. `NativeMonitor` follows PID/start/command identities across separate groups. The observed SwiftPM helper must name the expected private bundle and match its actual image hash/UUID; missing/wrong helper evidence fails. Cleanup reuses fresh identity checks before signaling. Saved ledgers cannot authorize disconnected helpers: the controller and native root must still match. Unknown children block replacement.

Each attempt retains raw logs, exact XML, profiles, actual child controls and process proofs. Temporary files live outside sealed proof and are cleaned only after a verified successful exit; failed/interrupted temporary data remains. Typed TMPDIR and profile-pattern bindings explain the two per-attempt substitutions. All static controls remain exact, including unknown ELITE/SWIFT/DYLD/LC controls. A leftover temporary file can no longer reject otherwise valid XML, while an unexpected proof file still fails.

## Admission and durability

One static slot namespace covers both modes and every controller. The immutable host policy binds explicit/CPU caps, reviewed RAM/disk capacities and reserves, and conservative maximum worker RSS/disk across every mode/build. Fresh availability is checked under the admission lock. Pending, launching and running reservations all remain charged; without trustworthy actual-use accounting, running workers retain their full future headroom charge. This is deliberately conservative and can admit fewer than two workers. It is not a memory reservation or speedup guarantee.

Reservations use generation nonces and atomic state changes. Pending precedes spawning; running requires observed process/image binding. Startup failure has durable no-launch evidence. Stale or unknown claims are reclaimed only after proven owner/descendant exit, never timeout alone. Disk admission includes retained artifacts and growth; no automatic eviction deletes current, inflight, upload or only-failure evidence.

Success requires integer exit zero, exact complete XML, exact source-declared opt-ins, no sanitizer diagnostics and unchanged runtime. Receipt, commit marker and containing directories are fsynced and sealed before indexing. Recovery rescans complete successes even when index/upload never happened. Failed and partial attempts remain and retries use new IDs. The durable host cache outside ephemeral checkout is primary hard-kill recovery; GitHub upload cannot guarantee recovery from a hard kill.

Full normal and leak phases use separate stable source/host/runtime-bound durable identities. Their runner captures host/head before a fresh invocation of the existing helper under exclusive preparation ownership and an empty phase cache. It requires actual completed native exits, exact full normal inventory, 80% coverage and zero leaks. Committed phase captures, including orphaned stages, validate and reuse before any broad execution. A retry or loss after capture before upload executes zero new phase bodies. Imported unbound legacy receipts cannot acquire execution-time host provenance.

## Parent authorization and child environment

The closed parent-only key list is:

```text
ELITE_RECOVERABLE_PLAN_SHA256
ELITE_RECOVERABLE_ASSIGNMENT_SHA256
ELITE_RECOVERABLE_ASSIGNMENT_PATH
ELITE_RECOVERABLE_REQUEST_MODE
ELITE_RECOVERABLE_REQUEST_SHARD
ELITE_RECOVERABLE_REQUEST_WORKER
ELITE_RECOVERABLE_REQUEST_PHASE
ELITE_RECOVERABLE_POLICY_SHA256
ELITE_RECOVERABLE_WORKFLOW_SHA256
ELITE_RECOVERABLE_ACTIVATION_SHA256
ELITE_RECOVERABLE_CODE_ENABLED
```

These eleven keys are introduced by this protocol solely for admission, assignment and hook attestation. Parent validation consumes them first; one helper physically removes them before every build, discovery, test, normal and leak command and records their original typed hashes separately. They are not a general environment-ignore list. Legacy `ELITE_NATIVE_APPROVED_HEAD`/`ELITE_NATIVE_POLICY`, test/build/opt-in controls and unknown ELITE keys remain in the actual child environment and hashes. The immutable shared execution-policy digest remains in the child. An environment self-assertion of CODE_ENABLED cannot override held source code or missing owned activation.

The extended native hook defaults to legacy CI-only authorization. New jobs require a host-owned activation with exact approved commit/ref, workflow file hash, expiry/revocation, fixed job allowlist, named runner/workspace, shared policy identity and assignment root. The separately installed guard and four helper files have SHA-256 pins and must also match GitHub blobs at the approved commit. The authorizer verifies the actual manual run, owner and triggering actor, run attempt, source/workflow and external artifact digest before issuing an owned immutable assignment. Prepare has no preexisting plan; later roles must match the authenticated frozen plan. Records bind role, source, workflow, policy path/hash, runner, workspace, run attempt, plan and exact selection. Individual records expire within eight hours and never outlive the reviewed activation. Valid issuance is idempotent; stale/conflicting/replayed records are rejected.

The workflow's first native step validates the external hook/owned assignment before checkout. Job environment self-hashes are not authority. User workflow input is only a default-false boolean; labels, shell, policy paths and shard selection come from fixed code and trusted owned plan data.

## Workflow and artifacts

The manual workflow first validates explicit activation on a hosted runner. Native jobs use future fixed controller/one/two labels, independent timeouts, `fail-fast: false` and at most two concurrent shard jobs. Preparation uploads a small digest-bound plan separately from each portable mode build. This avoids downloading full build data for each pre-job check. Full normal/leak phases precede shard jobs and have separate artifacts. Pending selection checks durable successes; all-complete plans skip native shard jobs, while empty/invalid plans fail.

Each shard restores only same-identity success, executes only missing/failed work, and always attempts to export/upload a sealed success or explicitly failed/incomplete raw attempt after authorized plan loading. Full-phase failures retain raw evidence too. Cancelled/failed jobs do not cancel independent workers. GitHub rerun-failed-jobs granularity is per matrix job, with durable proofs avoiding repeated bodies.

Artifact restore first authenticates run/head/attempt/owner/workflow and the complete ZIP SHA-256 from GitHub API metadata, then enforces size/free-disk bounds, safe physical paths, permissions and hashes. Only after that external trust anchor does it trust an internal index digest. Filenames alone are not identity. Portable mode restoration recreates only bound relative internal links and executable bits; arbitrary paths, links, cross-host data and changed build/runtime facts fail closed. Run-path validation handles GitHub's documented ref suffix while still binding the exact approved branch and source ([GitHub workflow-run API](https://docs.github.com/en/rest/actions/workflow-runs)).

The always-run native aggregator rehashes every required proof and exact inventory once per mode, plus full normal and leak gates. The final hosted physical qualification check rejects held, failed, cancelled and missing results. A skipped shard matrix is accepted only for a validated all-complete plan and successful native aggregate. Fake tests have a separate result and cannot become a physical pass.

## Local validation

64 focused fake-only test methods pass: 50 in `test_recoverable_shards.py` and 14 selected legacy/new authorization methods. They include real short Python child timeouts, inherited locks and controller exits, plus injected native command/SDK/process/API data. No Swift or game image is launched by these tests.

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tools/CI -p test_recoverable_shards.py -v
```

From `Tools/CI`, the selected guard tests are `test_native_runner.NativeAuthorizationTests`, `test_native_runner.PhysicalIdentityTests` and `test_native_runner.RecoverableAuthorizationTests`. Actionlint, YAML lint, paired Markdown lint and diff whitespace checks must also pass on the frozen packet. Raw logs and exact file hashes are retained in the Orchestrator manifest.

## Remaining activation and qualification

The actual planner, native adapters, pre-job authorizer, artifact transport and job routing source are implemented. Physical build, helper lifecycle, copied SwiftPM relocation, full native gates, throughput and operational credential availability are UNRUN. This PR remains draft/HELD and must not merge or dispatch during the current M01 campaign.

Activation requires a separate reviewed source change enabling the installed guard, provisioned exact runner/workspace instances and a shared owned policy/cache, pinned guard package/workflow bytes, approved activation/policy digests, external hook installation, relevant matching base controls, measured conservative capacities and reviewed external-resource audits. Static admission fields are `explicit`, `cpu_budget`, `ram_capacity`, `ram_reserve`, `peak_per_worker`, `disk_capacity`, `disk_reserve`, `disk_per_worker`. Optional source-bound `planning` contains only mode history/resource data and the soft target. The legacy cache must name the actual existing executor lock; a matrix alone does not create more physical workers. Configuration changes require a quiescent reviewed boundary; do not rewrite active claims or delete evidence.

The current M01 guard/policy/normal attestation remains immutable. This new guard changes authorization semantics and executable inputs, so that one-off attestation is not automatically valid here. A fresh authorization directory without that binding and separately authorized full normal execution are required; no attestor file or old receipt is normalized or migrated.

One indivisible consumer cannot checkpoint internally. If it exceeds a job's hard limit, reviewed test decomposition or a suitable execution service is required. Per-shard evidence never promotes partial XML. Existing review/protection, committed-main exact-SHA SonarQube and release requirements remain. Source publication uses `[skip ci]`; actual required checks must pass on the final head before any eventual protected merge. Generic review-service errors are neither code findings nor clean review. Independent G2 review of the coherent final source/fake packet remains required.

## Links

- [Motivation and acceptance](ISSUE-recoverable-parallel-quality.md)
- [PR #242](https://github.com/stephenlclarke/elite/pull/242)
