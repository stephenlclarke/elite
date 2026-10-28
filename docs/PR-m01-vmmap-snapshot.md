# feat(ci): retain bounded vmmap diagnostic custody

## Result

An explicitly reviewed local diagnostic session can collect one raw summary from the verified private ASAN helper while retaining the existing complete cohort and resource bounds. The dedicated result reports capture completion separately from the unanswered residency question and always records `ordinary_pass: false`. Ordinary success validation rejects both diagnostic authorization and the diagnostic runtime marker.

The controller uses one nonblocking event loop for the worker PTY, utility pipes, owned identity/RSS sampler and finite cleanup. It verifies the helper before capture and with a sample started after capture completion. It reuses the prepared image hash/UUID binding without launching a separate UUID utility. The captured helper binding is retained in shared custody state.

## Custody and admission

The fixed physical-home registry is owned, closed-schema and atomically replaced. An explicitly initialized valid empty registry allows ordinary admission. Missing, malformed, ACTIVE or UNKNOWN state refuses updated admissions and reservation reclaim. CLEAN requires bounded terminal absence and reaped direct children; unresolved spawn intents cannot become CLEAN. Registry readers never take the parent listener's controller flock.

A private in-process capability binds the exact consumed diagnostic session, attempt/nonce/current ACTIVE digest, controller PID/start/command/image/source, three actual lease acquisition witnesses, descriptor device/inode/open-file-description lifetime, deadline and timed phase. Reentry does not consume another allowance. Closed/replaced descriptors, wrong records, changed identities, deadline or UNKNOWN revoke it. Environment flags and bare descriptors cannot mint it.

If cleanup cannot prove absence and direct-child reap within its one window, the same controller persists UNKNOWN and holds the enclosing live leases. Its inert loop reads only the exact reviewed resolution material and waits. Interrupts and evidence-write exceptions cannot unwind unresolved custody. It does not sample, signal, spawn, retry capture, claim current RSS/identity or assert workload termination in that phase. SIGKILL/host death cannot retain dead descriptors; the persistent registry remains the later admission blocker.

The policy requires a reviewed deployment descriptor for current source and actual installed guard/controller/legacy/quality/hook bytes, the supported job matrix and quiesced old paths. It refuses missing coverage, old installed bytes or controller-needing listener jobs. This source packet does not update an installed listener or protect arbitrary manual commands.

Provisioning now acquires controller then the existing physical executor before the first git/tool/config action. Nested recoverable calls reuse only actual live in-process acquisition witnesses. Resuming registration checks the exact immutable issued ticket, session bounds, finite consumed state and repository registration. Registration/config releases the executor before `run.sh`; the parent retains controller custody. Actual workflow NativeAuthority jobs read the registry without reacquiring that controller. Local and provisioning calls reject listener-job environments before attempting their controller lock.

## Bounds and compatibility

- Worker trigger: 1,879,048,192 bytes; sampled union guard: 2,415,919,104 bytes; reserve: 2,147,483,648 bytes.
- One exact numeric-PID utility invocation; capture at most 10 seconds; one TERM/grace/revalidated-KILL/reap window at most 2 seconds; neither extends the cohort deadline.
- Combined vmmap stdout/stderr cap: 4 MiB. Each ready stream contributes at most 16 KiB per drain tick. Raw output is exclusive, owned mode 0600. Invalid UTF-8 or empty stdout is retained and classified incomplete.
- The explicit support process is the existing ps identity/RSS format, launched through the same owned controller path. Completed sampler pipes close and buffers are released. Historical identities and intents remain in custody evidence. The in-cohort reservation binding uses an immediate nonblocking claim rather than the ordinary 30-second admission wait. Before additional spawns, a 250,000-byte per-record evidence limit reserves space for UNKNOWN/terminal proof; terminal publication allows 700,000 bytes and registry publication allows 900,000 bytes beneath the reader's 1 MiB cap. Capacity exhaustion fails closed; it never drops identity history or extends the cohort. These limits can stop a long diagnostic before its cohort deadline.
- All observer overhead is unqualified until native measurement and remains inside the sampled union. No native permissions, residency columns, output schema, physical footprint, suspension cost or RSS cause is claimed.
- Without the diagnostic descriptor, ordinary policy/session, worker command and monitor behavior remain unchanged after the new shared-registry admission precondition. The fixed common provisioning executor must already exist; this patch creates no replacement executor or custody bootstrap.

## Validation

The saved `db197d77` run of `python3 -B -m unittest discover -s Tools/CI -p test_vmmap_snapshot.py -v` passed 31 focused test methods and exercised three selected existing fake ordinary reuse/runtime regression cases. That reviewed baseline is retained without a broad replay. All process creation, process probes and signal paths are faked; fixture files and lease FDs are temporary.

The cases cover closed policy/session rules, empty/missing/malformed/unresolved registry state, exact reviewed resolution and stale-record rejection, lease lifetime and same-inode FD reuse, consumed allowance and phase/deadline revocation, installed-byte/job-matrix drift, worker-only trigger, union accounting/reparent/PID drift, one capture and raw units, fair combined output cap, post-capture target sampling, invalid output/tool drift, aggregate refusal with cleanup, ten-second capture and original-deadline cleanup, TERM/KILL, interrupted inert custody, uncertain spawn and terminal persistence failure, missing-output reclaim without a native fallback, ordinary nonpromotion, nested/direct provisioning order, finite renewal and executor release before listener.

`git diff --check`, Python source compilation without bytecode output and Markdown lint pass for the frozen packet. Coverage measurement with the optional `coverage` module was unavailable in this interpreter; no percentage is claimed. `make ci`, native Swift assertions, sanitizers, leak gates, hosted checks, protected merge and release remain UNRUN/pending under Root/G1 ownership. No source-only result promotes the retained first Catalogue16 qualification or repairs the refused Panel16 result.

## Bounded review corrections

Review `557c727aecb2bf2b03ee2edfe2a5aea64f832b97ae61d2d9967ca6934ba6eb23` requested two corrections against `db197d77`; the other reviewed scope is retained. A worker/utility output error is recorded once and its acquisition stops, preserving the capped raw prefix. Cleanup still drains its independent identity sampler, polls owned direct children and uses fresh verified identities for the existing finite TERM/KILL/reap window. Output failure alone does not abandon those stop attempts. Failure to acquire trusted identity evidence still refuses signalling and retains unresolved custody.

The inert custody loop now waits after every unresolved check, including missing/malformed registry and invalid/stale resolution failures. An interrupted wait retries the wait before another file check. It retains all three lease lifetimes and performs no post-deadline native sampling, signals or work.

Five new correction methods plus four affected existing controller cases pass in one nine-method fake-only run. The new integrated cap case drives the actual bounded pipe-drain logic against fake ready descriptors until the combined 4 MiB limit, keeps output persistently available, ignores TERM and verifies fresh sampled KILL/reap inside the original cleanup window. It retains the exact raw prefix, returns diagnostic failure and avoids unjustified UNKNOWN. Missing/malformed/stale-resolution cases verify paced retries and held descriptors across an interrupted wait. A cleanup-only output exception case covers the separate cleanup catch path.

For a negative control, the reviewed old `drain`, `cleanup` and `custody_hold` methods were loaded into memory without changing tracked source. The persistent-cap and three hold regressions all failed as expected. Corrected methods pass. No unrelated tests, native probe, operator bootstrap/deployment or policy/session/resolution action was performed. The narrow correction packet changes only the affected controller, focused fake tests and this note pair; independent correction review is complete with no remaining source findings.

## Review handoff

Freeze exactly these seven paths for one independent MBA source review through Root. The owner must close actionable findings before integration. For any later pushed project PR, use the established single `@codex review` handoff for that pushed packet, disposition real code findings, retain required independent approval/checks and use a protected merge. Generic service errors receive the current human-directed disposition recorded in AGENTS.md.

Related issue: [M01 diagnostic gap and acceptance](ISSUE-m01-vmmap-snapshot.md). No GitHub PR is created by this source-only handoff.

## Final composition checkpoint

Independent review `c072799ffa9ffac237017a6cf113f560e694fd308c80705cf512697ab4ec1404` cleared correction e8b3b717 and retained the other db197d77 review. The original 2176 Catalogue16 sealed pass remains separately credited; the Panel16 RSS failure and counters 1/1/0 remain unchanged. G1 composes only tracked status documents onto the reviewed source in the existing owned Library checkout. No code or Swift test changes accompany that composition.

Before any native run, G1 must obtain the exact composition and bootstrap/deployment plan review, then actual installed guard/hook and old-launch-path clearance, then fresh finite preparation and actual-plan/execution-input review. Missing registry is intentionally a deployment blocker; old unguarded copies are not covered merely by adding the new source. No installed files, registry, old authority/evidence, policy/session, process or release changes occurred in this composition. Permission, output/residency schema and overhead remain unqualified.
