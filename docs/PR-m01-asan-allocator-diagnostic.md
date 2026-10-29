# Test-only ASAN allocator checkpoints

## Scope and gate

`ASANAllocatorDiagnostic` adds synchronous scalar checkpoints to the three existing `NativeMissionStationTests` methods and the existing seven-argument stale-authority salvage method. It adds no test method or product hook. The original statements, fixtures, assertions and argument lists remain unchanged after removing the diagnostic lines. `NativePagedSalvageFixture`, `Game` captures, Tools/CI, validators, package configuration and runtime options remain unchanged. [Evidence gap](ISSUE-m01-asan-allocator-diagnostic.md).

Only `ELITE_ASAN_ALLOCATOR_DIAGNOSTIC=1` enables it. Missing, empty or other values return before shared state, locks, symbol resolution, clock/thread queries or output. Ordinary callers retain only the gated call and a nil scalar token/defer. Actual diagnostic overhead remains unmeasured.

On Darwin arm64, the helper resolves exactly four public `size_t` counter getters and `__asan_print_accumulated_stats` through the already loaded process. It does not load another library. The C signatures match the independently pinned installed Apple headers; actual Swift compilation, ABI and runtime symbol availability remain unverified until G1's matching build/run. A missing symbol produces one bounded unavailable fact, stops logging and does not call counters or stats. No fallback probe runs. The Linux/x86_64-only experimental live-allocation profile is not used.

## Checkpoints and limits

Mission methods record entry, fixture-ready and body-exit. Salvage records entry, fixture-ready, hot-work-ready after the required current hot record, pre-final-flush after stale custody oracles, final-flush-done after the original flush/expectation, and body-exit. A phase marker records reaching that boundary; it does not establish an assertion pass or successful qualification.

The four invalid-anchor invocations plus two other mission methods produce 18 records. Seven salvage invocations produce 42. The expected complete trace therefore has 60 records. Both accumulated stats requests use existing checkpoints: the first diagnostic entry and the first salvage hot-work-ready boundary.

One process-wide state limits total checkpoint lines to 64, including unavailable, error and ceiling facts. Normal emission stops at 63; the next request spends the final slot on one `record-limit` fact and stops logging. Each line is at most 1,024 bytes. A failed write stops logging. No records or fixture objects accumulate in the helper. Counter/state emission uses a small lock that never crosses fixture construction, assertions, body execution or an await. The stats printer runs after releasing that lock. No test trait, scheduler or case serialization changes.

The helper takes only a fixed method tag, a whitelisted scalar argument, an invocation number and a phase. Deferred exit captures that scalar token. It accepts no `Game`, `Commander`, fixture, captured callback or snapshot. Search-attempt counting is intentionally absent: fixture-ready follows the unchanged search, contact checks and save-policy migration together. Their internal split and attempt count remain unknown.

## Output and interpretation

Each `ELITE_ASAN_ALLOCATOR_CHECKPOINT` line contains JSON with schema `1`, kind `asan-allocator-checkpoint-v1`, monotonic boundary and sampled times, PID/thread, invocation, exact method/argument, phase, availability/errors, the four raw byte counters and an optional stats-dump request index. The boundary timestamp is captured before shared-state contention where practical. The sampled timestamp follows the sequential getters. Stats requests carry the same checkpoint tags/time; raw printer output may interleave with other output.

The getters report ASAN allocator-wide application allocation, mapped heap, reusable/free bytes and unmapped bytes. They are sequential samples, not one atomic heap snapshot, whole-process RSS or case-owned bytes. Do not derive exact quarantine bytes from `heap - allocated - free`. Only explicit runtime stats support a quarantine observation.

A deferred body-exit checkpoint occurs before all local fixture values necessarily destroy. It is not post-deallocation evidence or a count of retained games. Complete tagged entry/exit intervals can show observed method-body overlap; they do not show object lifetime or attribute bytes to a case. Missing exit markers after a guard stop are censored. High counters alone do not establish a leak, allocator cause or fit.

All stderr remains in the existing raw log. No validator excludes the stats or diagnostic text. If those stats cause the unchanged sanitizer validator to refuse, retain that honest diagnostic failure. Even a successful diagnostic-gated attempt is diagnostic-only and cannot qualify an ordinary runtime with different environment/profile identity.

## Validation and native handoff

Fourteen external mocked-contract, parser and source-invariance checks pass. They exercise exact default-off gating, each missing symbol, the shared record cap and error stop, both stats limits, 60 complete checkpoints, sequential counter drift, invalid/malformed/duplicate/oversized records, invocation/phase errors, interleaved parameter intervals and censored streams. The oracle rejects deliberate wrong schema, ownership/destruction, counter and tag claims. Source checks recover both original test files exactly after removing checkpoint lines and verify only the five reviewed symbols. The actual Swift JSON string template is also parsed with both available and unavailable sample values. These checks model the producer and execute the offline Python parser; they do not execute or compile the Swift helper.

Swift compilation, runtime availability, actual checkpoint/stat output and affected native assertions are **UNRUN**. Diagnostic CPU/memory/output cost and native fit are **UNMEASURED**. This packet is development/validation pending and requests one independent frozen-source review through Root.

G1 alone owns actual reviewed bindings and execution. Freeze all tracked source, ledger and status notes before the final new head. Bind that head, the exact diagnostic gate, new input/runtime/policy hashes and separate storage to reviewed finite preparation and execution sessions. Preserve the same complete 16-method membership, all 3,403 selectors and required cohorts, 2.25 GiB ASAN worker budget plus 2 GiB reserve, existing admission and RSS monitor. Run at most one reviewed diagnostic attempt, do not launch AppKit, and stop for independent raw review. No budget escalation, counter reset, retry, result promotion or automatic follow-up profile is authorized. Future ordinary qualification requires diagnostic-off bindings and a fresh identity. The full ordinary quality, main analysis and release gates remain separate.
