# Recoverable parallel quality protocol (HELD draft)

## Problem and result

Serial, packing-index sanitizer batches make independent recovery and bounded parallel work difficult. This packet adds stable whole-unit plans, isolated attempt evidence, durable success recovery, trusted artifact import/export, bounded shared workers and strict aggregate validation. It reuses `sanitizer_checkpoints.py` for partitioning, XML, declared opt-ins, hashing and atomic writes, and `quality_phase_checkpoints.py` for full normal coverage and zero-leak validation.

The native builder, executor, descendant monitor, fresh full-phase runner and command adapters are implemented behind a disabled activation guard. The new manual workflow runs only Python fakes on hosted Linux. It has no push, pull-request or scheduled trigger, no native runner routing and no native job. Existing required CI remains authoritative. No physical execution or native performance result is claimed.

## Implementation

### Planning and identity

`recoverable_shards.py plan --input request.json --output plan.json` consumes `runtime`, `inventory` and optional `shared_groups`, `history`, `resources` and `budget_seconds` fields. The target must be 300 to 600 seconds. Historical durations are positive hints keyed by the hash of each sorted atomic selection; without them, planning is deterministic. Whole suites and supplied shared groups remain atomic in both modes. Known heavy units become singleton shards. The existing grouping source audit must run at physical preparation; the fake test checks the current AppKit and salvage source manifest without discovering or executing Swift tests.

Runtime fields are exact: `schema`, `mode`, `inputs`, `toolchain`, `sdk`, `host`, `os`, `architecture`, `image_sha256`, `image_uuid`, `environment`, `phase_environment`, `flags`, `policy`, `opt_in_policy`. SDK identity hashes its actual version and path; OS identity hashes release and version. Environment uses the existing helper's relevant-control hashes. The separate common phase environment preserves normal/leak controls while the sanitizer environment also binds the existing mode-specific ASAN setting. Inputs include all maintained executable sources and tooling. Neither helper changes nor unrelated tracked tool changes receive a hidden cache exemption.

Each shard ID hashes runtime, exact methods, atomic membership and source-bound resource policy. It excludes worker number, packing order, time estimates, total plan ordinal and current commit SHA. Receipts retain both the original tested head and the current qualification head. Reuse across heads requires identical bound executable inputs. Protocol schema 1 with policy `recoverable-parallel-shards-v1` is a new protocol; old schema-3/packing-index receipts are not promoted.

### Attempts, locks and recovery

`NativeAuthority` first enforces the activation guard, then calls the existing `native_runner.validate` against a host-owned policy outside the repository. It checks the approved clean controller head and requires explicit nonoverlapping cache/worker reservations. Hardware UUID, compiler, SDK, OS, inputs, image and static environment controls are revalidated. The current CI/workspace restrictions remain in force; repository input cannot grant another native workspace.

`NativeBuilder` takes the existing legacy cache's `executor.lock` exclusively and the new preparation claim before calling the existing build/discovery helper once per mode. It validates the existing shared-process manifest for both modes. Each authorized worker gets one private clone and copied scratch per mode, reused only while its frozen marker, inputs and image match. Internal relative build links are confined to the scratch tree; external/absolute links are refused. Incomplete preparation is retained and blocks replacement. No source copy occurs for each test shard. Workspace/database copies and failure retention must fit the reviewed disk admission bound.

`NativeExecutor` verifies the private workspace and current controller inputs before and after execution, builds the existing `--skip-build` whole-suite command and holds shared legacy/preparation claims plus its exclusive workspace claim. `NativeMonitor` persists controller/root PID, start, command and descendant identities, including separate process groups. It uses the existing cleanup helper, which checks fresh start/command identity before each signal. A saved ledger does not authorize a disconnected helper: both controller and native root must still match. Unknown/reparented helpers block replacements. These paths have fake command/ownership tests; actual Swift lifecycle qualification remains held.

Each attempt owns its raw log, XML, profiles, child environment and process proof. Temporary data lives outside the sealed proof at the durable cache's `temporary/<attempt ID>` path. Successful verified exits clean only that owned temporary directory; failed/interrupted attempts retain it. Legitimate leftover temporary files therefore cannot become unexpected proof files. `environment.json` records base and actual child control hashes plus typed bindings for the owned `TMPDIR` and `LLVM_PROFILE_FILE` pattern. Validation recomputes both substitutions and requires every static control to remain exact. It does not claim that the base and actual child environments are identical. Unexpected proof files remain rejected.

`execute_process` passes claim descriptors to a new process session and records explicit integer native exit status. Timeout terminates that session and fails; the native monitor separately checks and cleans verified descendants that created other groups. A cleanup or observation failure cannot become a success.

Success requires integer exit zero, exact XML including exact declared opt-in skips, no sanitizer diagnostics and unchanged verified runtime. All retained outputs are hashed. Receipt and commit marker use unique atomic temporary files and fsync; files/directories are sealed, directory entries are synced, and only then is success indexed. A restart scans and revalidates local successes, including a complete attempt lost before index/upload. Failed, uncommitted and invalid attempts never qualify. Retries get new attempt IDs and preserve earlier evidence.

The local cache must be one host-owned durable path outside ephemeral checkouts, shared by every controller and both modes on that host. Per-shard and workspace claims reject duplicates. External-resource claims wait for conflicting work; any unaudited unit excludes all other external consumers. A resource audit requires exact source hashes, an explicit reviewed declaration and file/preferences/port/save-path claims. The existing shared-process audit does not grant external independence. No source audit in this packet enables native overlap.

One pool covers both modes. `worker_limit` computes the minimum of explicit cap, CPU budget, `(available RAM - reserve) / peak worker RSS` and `(available disk - reserve) / worst-case worker disk`. One host slot namespace also bounds independent controllers. Its immutable policy binds host, explicit/CPU caps, RAM/disk reserves and conservative maximum worker RSS/disk across all modes. Different per-mode/controller estimates are rejected, even when the explicit cap matches. Only live available RAM/disk observations may vary. Policy changes require a separately reviewed fresh cache/reservation with no active old work. Native admission reads CPU and VM-page counts plus free cache disk after authorization; the VM-page estimate is admission evidence, not a memory reservation. Admission cannot evict evidence or cancel existing work. The initial cap is at most two and must be reviewed per host; the proposed MBA cap is one. Measured peaks/reserves and the canonical cache/workspace policy are activation inputs, never guessed capacities. No automatic eviction is implemented; full disks block admission. Retention must preserve current/inflight work, pending uploads and the only failure copy.

### Artifact and aggregate contracts

`Store.export` emits one sealed shard bundle and returns its index SHA-256. The trusted digest must be retained outside that artifact by the authorized job/controller. Restore validates this external digest, exact index/path/identity, ownership, permissions, absence of symlinks, receipt hash and all output hashes. Archive filenames do not establish identity. Unpacked owner-writable files are validated in quarantine, then sealed locally. Cross-host promotion is rejected by runtime identity. Upload is best effort; the durable host cache covers the hard-kill gap.

`aggregate` requires exact successes for both thread and address plans and identical inventory once per mode. `NativePhaseRunner` records the host/head before invoking the existing full normal/leak helper under exclusive preparation ownership and an empty unique phase cache. It requires a fresh receipt at that approved head with successful native and overall exits. `freeze_phase` requires that execution origin; it cannot relabel an arbitrary imported legacy receipt as this host's execution. The externally anchored phase manifest binds host, origin and receipt hash. Aggregate also matches executable inputs, compiler, SDK, OS, architecture and the common phase environment, and checks full normal inventory, opt-ins, parallel coverage policy and zero-leak policy. Only dependency scratch prefixes before `/checkouts/` normalize for comparison; dependency contents and original identities remain bound. Legacy receipts without verified execution-time host capture do not establish this host binding.

### Implemented native commands (all HELD)

Every command below first fails at the disabled guard, before policy inspection or native probes. After a separately reviewed activation, the implemented paths are:

- `prepare --mode ... --output ...`: actual exclusive build/discovery, reused private workers and a plan; prints the plan SHA-256 for trusted job-output transport. Optional input supplies only duration/resource hints.
- `worker --input ... --digest ... --worker ... --shard ...`: one exact planned shard with strict resume. `pool` consumes a digest-bound manifest of plan paths/digests and shares one bounded pool across modes.
- `export`: one shard bundle plus its index SHA-256. `restore`: explicit artifact and separately trusted index digest, without execution.
- `phase --phase normal|leaks --worker ... --output ...`: fresh full legacy phase with execution-time host provenance, then a sealed phase proof and printed manifest digest.
- `aggregate`: digest-bound plan/proof manifest, exact both-mode successes, full normal coverage and zero leaks; also revalidates the prepared native runtime against the current approved controller.

Native commands require a host-owned policy's `recoverable_shards` object with `schema`, hardware UUID `host`, durable `cache`, actual existing `legacy_cache`, named `workers` base paths and `admission`. Static admission fields are `explicit`, `cpu_budget`, `ram_reserve`, `peak_per_worker`, `disk_reserve`, `disk_per_worker`; byte values must cover the maximum across builds and both modes. Native job wiring must capture printed digests through trusted job outputs, never read its trust anchor back from the artifact it authenticates. No command dispatch or policy creation happens in this packet.

### Manual workflow

`recoverable-quality.yml` is manual-only and hosted-only. Six independent fake contract families use `fail-fast: false`, `max-parallel: 2`, individual timeouts and always-run per-family log uploads. Native adapter tests stub every native command; only Python fake children execute. The always-run fake aggregator requires every family to pass. These jobs validate protocol behavior, not native quality, throughput or playable completion. This packet does not dispatch them.

## Validation

Run the focused fake suite from the repository root:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tools/CI -p test_recoverable_shards.py -v
```

Current local result: 36 fake-only tests pass, including real Python controller exits around XML/receipt/index/upload boundaries, zero-execution success restoration, failed-only retry, owned Python timeout, inherited lock survival, exact declared skips, tampered evidence rejection, resource serialization and full aggregate proof failure. Adapter tests cover actual command construction, build-once/private-scratch reuse, image/controller-input drift, separate-group descendants, PID reuse, disconnected helpers, pre-probe authorization, fresh phase origin and trusted plan/artifact CLI transport. G2's temp-file and unequal cross-mode peak counterexamples have positive/negative regressions. Swift/native builds, coverage, sanitizers, leaks, performance, GUI and physical-host probes are deliberately unrun under the active M01 hold. The existing 80% normal coverage gate remains unchanged.

## Compatibility and remaining activation work

This is a held implementation draft, not an enabled execution path. All native CLI entry points fail closed. Actual builder/executor/monitor/full-phase/CLI code is implemented; physical qualification is unrun. Before activation, G1 must be terminal and G2 must independently review the coherent final packet and corrections. The next separately reviewed activation must provision the host-owned workspace/cache/admission policy; qualify real copied SwiftPM scratch relocation, helper lifecycles and inherited claims; measure disk/RSS/CPU headroom; and review external-resource independence. It must preserve existing host authorization rather than bypass its exact checkout/workflow restrictions.

Real independent per-shard GitHub job routing and upload steps are not added to the fake-only workflow under this assignment's hold. Activation must wire the implemented exact-head plan/artifact commands and trusted digest outputs to authorized per-shard runner instances, immediate uploads and an always-run required native aggregator. A single runner instance will queue jobs. The implemented local pool offers bounded execution but does not provide GitHub per-shard retry granularity. This draft's fake matrix is not a substitute for that integration. An indivisible long consumer that exceeds a job limit requires reviewed test decomposition or an appropriate execution service; partial XML cannot become a pass.

Before any eventual merge: request `@codex review`, resolve actual findings, complete independent bug/performance/style/recovery review and pass the required checks on the final head. Generic review-service errors are not code findings or clean review. Main-only committed-SHA SonarQube and release gates remain unchanged. Source publication uses `[skip ci]` and a draft PR targeting `release/m01`; do not merge or activate this packet during M01.

## Links

- Motivation and acceptance: [ISSUE-recoverable-parallel-quality.md](ISSUE-recoverable-parallel-quality.md).
- PR URL and final review evidence will be recorded by the Orchestrator after publication.
