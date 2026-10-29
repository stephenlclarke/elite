# M01 full-quality bridge for original local sanitizer proof

> Superseded CI routing: the user removed ASAN and TSAN requirements on 28 October 2026. The active workflow no longer consumes this sanitizer bridge. The contract and results below are retained as history; see [current CI scope](PR-ci-without-sanitizers.md).

## Result

The explicit `owned-local-components-v1` backend combines complete original local ASAN/TSAN components with real current-CI prerequisites, normal coverage and zero-leak phases. Original sanitizer proof retains its tested head H. Current CI phases retain actual head M. An owned binding permits H-to-M use only when their complete Git trees and all canonical executable/dependency blobs match exactly. The bridge never claims that a sanitizer executed at M when its receipt records H. [Problem and acceptance criteria](ISSUE-m01-local-quality-bridge.md).

The absent-backend default remains `github-artifacts-v1`, with the existing full-seven-role or ASAN-three-role installer profiles, sanitizer matrices and two-plan aggregate. The selected backend has exactly five roles: `native_checks`, `prepare_address`, `native_local_components`, `native_phase` and `native_aggregate`.

## Owned binding contract

Only G1 creates and activates the independently reviewed binding. It is an owned physical `0400` JSON file at the physical account's `~/Library/EliteNativeAuthorization/local-quality-bindings/{M}/binding.json`. Its raw SHA-256 descriptor, with exactly `path` and `sha256`, appears in the installed activation, published manifest and owned job assignments. It must remain disjoint from mutable CI execution storage. Its finite expiry must be current and no later than the current activation expiry.

| Field | Exact content |
| --- | --- |
| `schema`, `kind`, `expires_at` | `1`, `owned-local-components-v1`, finite current deadline |
| `target` | Exactly `head`, `ref`, `tree` for actual CI execution M |
| `original` | Exactly `head`, `tree` for original local execution H; tree equals target tree |
| `inputs` | Complete canonical executable/dependency input map |
| `semantic_environment` | Complete compatible semantic parent environment, as hashed runtime values |
| `ci_admission` | Exact current CI admission allocation |
| `phase_profiles` | Exact independently reviewed normal and leak profiles |
| `modes` | Exactly `address` and `thread`, each with the descriptor fields below |

Each mode entry has exactly `policy`, `plan`, `component`, `build`, `cache`, `worker`, `runtime_sha256` and `admission`. `policy` and `plan` are `path`/raw-`sha256` pairs for original immutable files. `component` and `build` are `path`/raw-`sha256` pairs for original directories and their `component.json` or `build.json`. Other fields bind the original store, private worker, complete runtime fingerprint and separate mode allocation. These values come from actual completed local preparation and qualification. Synthetic planner projections cannot supply them.

The verifier checks both Git objects, both clean source checkouts, canonical input maps, all five original helper pins, original private image/source, immutable frozen scratch layout and dependencies, component commits and every original sealed shard. It recomputes the full exactly-once inventory union, strict XML/opt-in/diagnostic validation, native exit, observed image UUID/hash and mode-specific sampled RSS. It checks each original local policy/session window at the recorded child execution time. Original policy expiry after execution does not reopen or invalidate historical authority; the separate bridge binding must still be current.

The read-only store, tree and scratch paths cannot create missing original storage. Focused fakes fail if the pure verifier attempts directory creation, proof writes, copying, a new `LocalAuthority` or a real subprocess. Original policy, plan, store, component, authorization and tested-head fields stay untouched. Only the new current-CI verification report is written.

Only four authority identity environment fields may differ: `ELITE_NATIVE_POLICY`, `ELITE_NATIVE_APPROVED_HEAD`, `ELITE_RECOVERABLE_LOCAL_POLICY_SHA256` and `ELITE_RECOVERABLE_EXECUTION_POLICY_SHA256`. Their underlying policy/head/profile facts are separately validated. Unknown `ELITE_` controls, opt-ins, `HOME`, `PATH`, toolchain/SDK/OS identities and sanitizer options remain bound. Derived ASAN `detect_leaks=0` is checked separately. Incompatible parent environments refuse; there is no broad option stripping.

## Actual CI routing and aggregate

The selected backend prepares a real current-M address build/discovery/private-image anchor. Its manifest explicitly says `anchor_only`; its pending sanitizer selections remain pending. It does not manufacture a thread plan or an ASAN pass.

`native_local_components` loads that authenticated anchor and reverifies both originals under actual current CI authority and the existing physical lease. Only its successful explicit `verified=true` result allows the selected branch to proceed. `prepare_thread`, `thread_shards` and `address_shards` intentionally skip in this branch. The outcome closure and physical qualification job require exactly those skips, successful verification, a real address anchor, prerequisites, phases, aggregate and hosted fake results. A missing/failed/cancelled verifier, wrong backend or any other skipped required work refuses.

Normal and leak jobs load the real address anchor. The explicit aggregate reverifies the original components again, requires sealed current-run prerequisite evidence with the original Make target list and actual `native_checks` origin, and validates both actual-current-M phase capsules. It exports their coverage only after content validation. Reports distinguish original sanitizer H from phase M and remain pending the real outcome closure and actual-main analysis.

`make ci-owned-local-components` invokes this same actual-authority aggregate. It then invokes the existing `make sonar` only for actual main outside a PR. The workflow requires job/fake outcomes before that invocation and installs SonarScanner on main. The default `make ci` dependency list, `.github/workflows/ci.yml`, the release publisher and old normal-attestation helper remain unchanged. No manual status or protection bypass is added.

## Separate normal and leak working-set profiles

The selected policy requires `recoverable_shards.phase_profiles` with exactly `normal` and `leaks`. Each has exactly `build_profile=jobs1-nonbatch-v1` and its own complete admission dictionary: `explicit`, `cpu_budget`, `ram_capacity`, `ram_reserve`, `peak_per_worker`, `disk_capacity`, `disk_reserve` and `disk_per_worker`. Each reserves one worker and one compiler CPU. The selected CI policy and both original mode policies must name the physical account's existing `~/Library/EliteNativeCI/sanitizer-checkpoints` executor lease. An alternate lease path refuses before native routing. Both profiles are separately pinned in the bridge binding and execution-policy identity. Missing or invalid profiles refuse; neither inherits the ASAN allocation.

Only build arguments gain `--jobs 1 -Xswiftc -disable-batch-mode`. The normal command keeps code coverage, skip-build execution and its existing concurrency; leaks keeps `/usr/bin/leaks --atExit -- <actual-image> --diagnostics`. Actual build argv, image path, profile, allocation and policy digest enter phase identity. Captured build logs and actual native commands are validated. Full normal inventory/opt-ins, the 80 percent coverage gate, diagnostics, successful native exits and zero leaks remain required. The selected backend does not use the old one-off normal attestation.

The existing owned monitor samples the whole phase descendant tree, including compiler and runtime children, against that phase's budget. Missing/incomplete samples, over-budget use, wrong phase/profile/budget or failed cleanup refuse. Normal additionally requires its exact observed helper image/UUID. Each sealed capsule includes hashed phase-memory evidence and the actual parent authorization and process terminal. Default phase capsules retain their original schema and behavior.

## Validation and handoff

All 63 selected fake tests pass with zero failures, errors or skips. Twenty-two new cases cover the bridge, selected authority and phase profiles. Affected/default tests cover workflow routing, native adapters, phase validation, legacy normal/leak behavior, original local component qualification, pre-job authority and the unchanged publisher's missing-quality refusal. The original broader local adapter/startup/TSAN packet evidence remains retained for unaffected scope. Fake memory refusals in the log are intentional negative cases. Python line coverage was not measured because the coverage package is unavailable; no native coverage claim follows from these Python results.

The durable MC1 packet contains individual test IDs, timings, source hashes, raw fake output and static-check evidence. No native build/compiler/test, game/GUI, resource/hardware/process probe, live API, operator state change, publication or release ran. G1 retains `make ci` and the remaining actual full-quality gates under its reviewed execution lease.

Freeze every tracked file, including these notes and Root's ledger changes, before local preparation. Any later tracked-tree change rejects H-to-M bridging, even a documentation-only edit. After independent frozen-source review, G1 publishes the final common local source, obtains actual mode policy/session and bridge/phase binding review, qualifies ASAN first and TSAN second, and completes actual CI/main analysis and release gates. The candidate per-phase 2 GiB plus 2 GiB allocations remain unmeasured; this source packet does not establish native qualification or playable release completion.
