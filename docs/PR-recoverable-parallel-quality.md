# Recoverable parallel quality protocol (HELD draft)

## Problem and result

Serial, packing-index sanitizer batches make independent recovery and bounded parallel work difficult. This packet adds stable whole-unit plans, isolated attempt evidence, durable success recovery, trusted artifact import/export, bounded shared workers and strict aggregate validation. It reuses `sanitizer_checkpoints.py` for partitioning, XML, declared opt-ins, hashing and atomic writes, and `quality_phase_checkpoints.py` for full normal coverage and zero-leak validation.

Physical execution remains disabled. The new manual workflow runs only Python fakes on hosted Linux. It has no push, pull-request or scheduled trigger, no native runner routing and no native job. Existing required CI remains authoritative.

## Implementation

### Planning and identity

`recoverable_shards.py plan --input request.json --output plan.json` consumes `runtime`, `inventory` and optional `shared_groups`, `history`, `resources` and `budget_seconds` fields. The target must be 300 to 600 seconds. Historical durations are positive hints keyed by the hash of each sorted atomic selection; without them, planning is deterministic. Whole suites and supplied shared groups remain atomic in both modes. Known heavy units become singleton shards. The existing grouping source audit must run at physical preparation; the fake test checks the current AppKit and salvage source manifest without discovering or executing Swift tests.

Runtime fields are exact: `schema`, `mode`, `inputs`, `toolchain`, `sdk`, `host`, `os`, `architecture`, `image_sha256`, `image_uuid`, `environment`, `flags`, `policy`, `opt_in_policy`. SDK identity hashes its actual version and path; OS identity hashes release and version. Environment uses the existing helper's relevant-control hashes. Inputs include all maintained executable sources and tooling. Neither helper changes nor unrelated tracked tool changes receive a hidden cache exemption.

Each shard ID hashes runtime, exact methods, atomic membership and source-bound resource policy. It excludes worker number, packing order, time estimates, total plan ordinal and current commit SHA. Receipts retain both the original tested head and the current qualification head. Reuse across heads requires identical bound executable inputs. Protocol schema 1 with policy `recoverable-parallel-shards-v1` is a new protocol; old schema-3/packing-index receipts are not promoted.

### Attempts, locks and recovery

An injected, reviewed executor must verify actual runtime facts before and after execution; report its PID/start/image identity; refuse unknown live helpers; prove prior owners and descendants have exited; and retain claim descriptors in its child. A workspace claim prevents concurrent use of a writable scratch/database. `freeze_build` requires the adapter's exclusive preparation claim before building/discovering once and writing a sealed manifest. No native adapter is activated by this packet.

Each attempt owns its raw log, XML, profiles and process proof. `execute_process` creates unique temporary/profile directories, passes claim descriptors to a new owned process session, and records a terminal process exit. Timeout terminates only that session and returns failure. This Python primitive alone does not prove that every Swift descendant remains in the session; the native activation must qualify that behavior or reuse the existing owned-descendant cleanup.

Success requires integer exit zero, exact XML including exact declared opt-in skips, no sanitizer diagnostics and unchanged verified runtime. All retained outputs are hashed. Receipt and commit marker use unique atomic temporary files and fsync; files/directories are sealed, directory entries are synced, and only then is success indexed. A restart scans and revalidates local successes, including a complete attempt lost before index/upload. Failed, uncommitted and invalid attempts never qualify. Retries get new attempt IDs and preserve earlier evidence.

The local cache must be one host-owned durable path outside ephemeral checkouts, shared by every controller and both modes on that host. Per-shard and workspace claims reject duplicates. External-resource claims wait for conflicting work; any unaudited unit excludes all other external consumers. A resource audit requires exact source hashes, an explicit reviewed declaration and file/preferences/port/save-path claims. The existing shared-process audit does not grant external independence. No source audit in this packet enables native overlap.

One pool covers both modes. `worker_limit` computes the minimum of explicit cap, CPU budget, `(available RAM - reserve) / peak worker RSS` and `(available disk - reserve) / worst-case worker disk`. One host slot namespace also bounds independent controllers. Admission cannot evict evidence or cancel existing work. The initial cap is at most two and must be reviewed per host; the proposed MBA cap is one. Measured peaks/reserves and the canonical cache/workspace policy are activation inputs, never guessed capacities. No automatic eviction is implemented; full disks block admission. Retention must preserve current/inflight work, pending uploads and the only failure copy.

### Artifact and aggregate contracts

`Store.export` emits one sealed shard bundle and returns its index SHA-256. The trusted digest must be retained outside that artifact by the authorized job/controller. Restore validates this external digest, exact index/path/identity, ownership, permissions, absence of symlinks, receipt hash and all output hashes. Archive filenames do not establish identity. Unpacked owner-writable files are validated in quarantine, then sealed locally. Cross-host promotion is rejected by runtime identity. Upload is best effort; the durable host cache covers the hard-kill gap.

`aggregate` requires exact successes for both thread and address plans and identical inventory once per mode. `freeze_phase` captures an existing full normal or leak proof only through an executor that verifies the actual host at capture. Its externally anchored manifest binds host and receipt hash. Aggregate also matches executable inputs, compiler, SDK, OS, architecture and environment, and checks the original full normal inventory, opt-ins, parallel coverage policy and zero-leak policy. Only dependency scratch prefixes before `/checkouts/` normalize for comparison; dependency contents and original identities remain bound. Legacy receipts without verified host capture do not establish this host binding.

### Manual workflow

`recoverable-quality.yml` is manual-only and hosted-only. Five independent fake contract families use `fail-fast: false`, `max-parallel: 2`, individual timeouts and always-run per-family log uploads. The always-run fake aggregator requires every family to pass. These jobs validate protocol behavior, not native quality, throughput or playable completion. This packet does not dispatch them.

## Validation

Run the focused fake suite from the repository root:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tools/CI -p test_recoverable_shards.py -v
```

Current local result: 25 fake-only tests pass, including real Python controller exits around XML/receipt/index/upload boundaries, zero-execution success restoration, failed-only retry, owned Python timeout, inherited lock survival, exact declared skips, tampered evidence rejection, resource serialization and full aggregate proof failure. Swift/native builds, coverage, sanitizers, leaks, performance, GUI and physical-host probes are deliberately unrun under the active M01 hold. The existing 80% normal coverage gate remains unchanged.

## Compatibility and remaining activation work

This is a held implementation draft, not an enabled execution path. Both physical CLI entry points fail closed. Before activation, G1 must be terminal and G2 must independently review the coherent final packet. The next separately reviewed change must supply and qualify the actual host/runtime builder and executor adapter; authorized independent checkout/scratch instances; image/source/environment revalidation; PID/start/image/descendant ownership and dead-owner proof; disk/RSS/CPU measurements; and audited external-resource claims. It must preserve the existing host authorization rather than bypass its exact checkout/workflow restrictions.

Real independent per-shard GitHub jobs, exact-head plan/artifact manifests, trusted digest transport, immediate per-shard upload and an always-run required native aggregator also remain activation work. A single runner instance will queue jobs. A local pool offers bounded execution but does not provide GitHub per-shard retry granularity. This draft's fake matrix is not a substitute for that integration. An indivisible long consumer that exceeds a job limit requires reviewed test decomposition or an appropriate execution service; partial XML cannot become a pass.

Before any eventual merge: request `@codex review`, resolve actual findings, complete independent bug/performance/style/recovery review and pass the required checks on the final head. Generic review-service errors are not code findings or clean review. Main-only committed-SHA SonarQube and release gates remain unchanged. Source publication uses `[skip ci]` and a draft PR targeting `release/m01`; do not merge or activate this packet during M01.

## Links

- Motivation and acceptance: [ISSUE-recoverable-parallel-quality.md](ISSUE-recoverable-parallel-quality.md).
- PR URL and final review evidence will be recorded by the Orchestrator after publication.
