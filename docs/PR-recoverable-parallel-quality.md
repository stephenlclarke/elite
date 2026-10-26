# PR #242: granular native quality and recovery

## Problem and result

One opaque `make ci` job shares a hard limit across normal tests, TSAN, ASAN and leaks. The retained M01 ASAN group 11 had 96 selected IDs and remained incomplete after 9,789 seconds. Earlier completed work needs independent GitHub results and durable recovery boundaries.

[PR #242](https://github.com/stephenlclarke/elite/pull/242) now routes the real CI events through the existing recoverable workflow. `.github/workflows/ci.yml` preserves its triggers, concurrency policy and required job named `quality`. That final job requires the actual reusable component workflow to succeed. It does not copy a status or qualify missing/skipped work. This change remains isolated from the running f9 M01 candidate.

## GitHub execution boundaries

- A hosted authorization gate checks the exact internal event, actor, execution head/ref and reviewed activation before native routing.
- `native_checks` runs every original non-phase `make ci` prerequisite: native guard, instance equality, crash capture, flight controls, distribution, ships, showroom and mission-pack checks. Existing sanitizer/phase/normal-attestation fake gates also remain.
- `prepare_thread` and `prepare_address` have separate build and discovery/freeze steps. An owned build checkpoint lets discovery use `--skip-build`. The previously reviewed complete frozen bundle/private worker restoration remains the primary durable preparation proof.
- Full normal tests plus the existing 80% coverage gate and zero leaks remain separate jobs. Their complete phase receipts are independently recovered and uploaded.
- `thread_shards` depends only on thread preparation; `address_shards` depends only on address preparation. Each matrix job has its own result, raw log/XML/receipt upload, 7,200-second execution bound and 130-minute job limit, leaving ten minutes for export and upload. `fail-fast: false` retains healthy work after another shard fails.
- The native aggregate revalidates both independent plans, exact complete inventories, every shard, full normal coverage and zero leaks. Only then does it export the hash-validated normal coverage for actual-main Sonar analysis. `make sonar` retains the committed-main/exact-SHA guard.
- The always-run hosted final aggregate rejects missing, failed or cancelled prerequisites. A skipped shard matrix is accepted only for a validated no-pending plan with a successful native proof aggregate.

Every native job uses the existing `self-hosted/macOS/ARM64/elite-native` route. The initial activation has one registered physical runner, one private worker and `explicit=1`; each matrix has `max-parallel: 1`. The existing global executor lock and reviewed host CPU/RAM/disk admission remain. Independent GitHub jobs do not imply physical parallelism. No current native lease is shared or modified.

## Packing and the actual long ASAN group

The default count cap is 64 IDs across whole atomic units, alongside the existing soft 300-600 second planning budget. Supplied measured atomic history overrides the deterministic count-only fallback of eight seconds per ID. That fallback is a packing weight, not a runtime measurement or completion prediction. Ordinals, labels and timing hints do not enter the existing stable execution identity.

A source-only projection of the retained 3,403-ID inventory yields 52 shards per mode, rather than the initial 236-per-mode proposal. The former 96-ID group contains 20 suites. Its three `NativeMissionMenuTests` cases belong to the existing 170-ID AppKit shared-process group, which remains whole; the other 19 suites retain their whole-suite boundaries. In the complete deterministic plan those 96 IDs intersect 15 shards: one AppKit shard and 14 ordinary shards of at most 64 total IDs. No method duration or independence was inferred from the partial log tail. The 13-ID salvage shared-release group also remains indivisible.

The AppKit dependency is shared `NSApplication` and MainActor renderer caches. The salvage dependency is `NativeSalvageReleaseSnapshot.shared` actor/task. Existing source-hash audits and exact grouping/inventory validation remain mandatory in both modes. Whole suites and these groups are never split to meet a count or duration target.

An indivisible unit may exceed 64 IDs. It still has the same hard execution bound. A proven exact-identity timeout of such a unit becomes a precise blocker naming the cohorts and retained attempt; the next identical request stops before automatic replay. Review must establish safe test/shared-state decomposition or a different approved execution bound. A hard limit cannot checkpoint inside a running test, and no throughput or native completion claim is made. Packed multi-atom failures may be replanned through reviewed atomic planning hints while successful unchanged shard identities remain reusable.

## Proof, artifacts and progress

The reviewed protocol remains `recoverable-parallel-shards-v1`. It binds actual maintained source/tools/workflow/dependency inputs, compiler, SDK path/version, physical host, OS, architecture, actual image hash/UUID, flags, opt-ins, exact methods, grouping and relevant runtime controls. Real observed helper image/path/UUID, owned descendant tracking, inherited claims, static host admission and sealed durable build/phase/shard receipts remain in use. Failed/partial XML, nonzero exits, sanitizer diagnostics, unexpected skips, low coverage and nonzero leaks cannot qualify.

Durable host proof outside `.build` is primary recovery after a hard kill. `always()` exports/uploads retain immutable raw preparation attempts, prerequisite results, phase logs/XML and each shard outcome independently. GitHub artifacts are restored only after exact run/head provenance and the API's external ZIP digest, followed by safe-path/size checks and internal content validation. The small plan artifact is independent of portable mode builds, so each shard does not download a full build. Existing private copies are reused rather than copied for every shard. Cancellation cannot erase already committed durable proof, but upload itself cannot be guaranteed after an abrupt host kill.

Job names identify cohorts, ID counts and a stable hash. `GITHUB_STEP_SUMMARY` and stdout show validated completed/total shard counts, the current shard and any indivisible-cohort limitation. Always-run export refreshes the count after an execution failure. Progress is not inferred from an unfinished method log. Full phases report their own status without inventing partial-phase passes.

## Exact-head authorization and G1 transition

The code path is now available rather than permanently disabled in source. It still requires the separately installed owned exact-job authorization before policy inspection/native probes. A workflow environment flag cannot grant execution. The existing eleven parent-only assignment controls remain physically absent from native child environments; legacy approval/path and unknown relevant controls remain exact and hashed. No cross-SHA exception, f9 proof promotion or old 7eb normal-attestor migration is added.

The existing installed guard package is reused with narrow explicit roles for mode preparation, checks, phases, each mode's shards and aggregate. Trusted push-main and internal PR events are now supported. For a PR, `approved_head` is the exact execution merge commit and `pr_head` independently pins the internal PR source; the event must bind both. GitHub run/artifact metadata binds the PR source head while receipts still bind the execution head. Main push requires its exact nonforced/nondeleted main commit. An external/fork/target event fails closed.

G1 owns this concrete transition after independent review at a quiescent boundary:

1. Preserve the current M01 run/policies/cache unchanged. Compose the reviewed workflow source into the future candidate; rebase/source-audit as required. The source change invalidates old executable-input keys. Required checks must qualify the actual candidate and actual main independently.
2. Prepare the owned policy at `~/Library/EliteNativeAuthorization/<execution-head>/policy.json` using the existing verified runner archive, exact physical workspace and current approved compiler/SDK. Do not mutate an existing authorization. Retain one runner instance, private worker `one`, the actual legacy `executor.lock` location and reviewed static capacities/reserves.
3. Install the five pinned Python guard/helper files outside mutable checkout/cache. The guard SHA, four helper SHA-256 pins, exact `ci.yml` caller SHA and separate `reusable_workflow_sha256` must match the approved commit. Configure the owned pre-job hook to invoke that installed `native_runner.py --policy <owned-policy>` before any checkout.
4. The owned `recoverable_activation` must pin schema/enabled/revoked/expiry, execution `head`, actual caller `workflow_ref`, caller `workflow_sha256`, `reusable_workflow_sha256`, reviewed manifest digest, physical host and assignment root. For PRs also pin `pr_head`. The trusted `ELITE_RECOVERABLE_ACTIVATION` JSON carries the same facts plus exact `ref` and `workflow_file` (`ci.yml` for CI); `ELITE_RECOVERABLE_POLICY_DIGESTS` maps the one runner name to the full owned policy digest. The existing authorizer authenticates GitHub source/tool blobs and both workflow files before issuing immutable run-attempt assignments. Aggregate assignments additionally bind the independent address-plan digest.
5. Allow only `native_checks`, `prepare_thread`, `prepare_address`, `native_phase`, `thread_shards`, `address_shards` and `native_aggregate` on that exact runner/workspace. Register/listen serially under G1's existing lease; an ephemeral `--once` runner needs renewed registration between jobs, never concurrent instances. The hook must have scoped read access to the actual run/artifacts before checkout; missing credentials fail closed.
6. Trigger only the separately authorized exact-head future CI event. Confirm all prerequisite, phase, shard, artifact and aggregate outcomes in the ordinary required `quality` route. Keep branch protections intact; do not replace required checks with a manual demonstration. Native copied-build/helper lifecycle and packaging/release remain independently validated work. Only G1 installs policies, changes routing variables or starts physical execution.

No installation, variable change, workflow dispatch, native build/test/probe, benchmark or current-run mutation is performed by this source packet. The new delta needs independent MBA review before activation. Earlier source clearance for `febc2c78` applies only to its retained scope, not automatically to this delta.

## Focused validation and limits

The earlier 64 fake-only pass records remain retained. 28 current affected fake-only tests pass, including ten new cases. They cover the changed mode-plan routing, build/discovery recovery, actual CI authorization, both-plan assignment binding, whole-unit bounded packing, immutable failure export, progress and strict final gate. Only affected fake cases and workflow/YAML/paired Markdown/whitespace checks run locally. Raw counts and exact hashes accompany the frozen Orchestrator handoff. No broad or native test result is claimed.

Actual copied SwiftPM relocation, installed pre-job credentials, runner lifecycle across jobs, full native gates and speed remain unverified. A source-only count projection is not evidence of faster completion. Any changed source, dependency, environment, generated version/resource, image, UUID or authorization refuses old proof. Actual-main Sonar and signed/notarized release stages retain their existing requirements.

See [motivation and acceptance](ISSUE-recoverable-parallel-quality.md).
