# Recoverable parallel quality execution

## Motivation

The current sanitizer helper runs whole-suite groups serially under one executor lock. A failed or interrupted long campaign can leave later groups unexecuted, and GitHub retries operate at the campaign job boundary. Existing complete checkpoint receipts help local recovery, but their packing-index identity does not provide stable independent shard jobs.

The reviewed planning sample contained 3,403 methods in 36 groups. Twelve completed groups took about 9,212 seconds in total, with one indivisible consumer taking about 5,099 seconds. Two workers cannot remove that consumer's duration. These are retained planning observations, not performance measurements of this change.

## Requested behavior

- Pack whole suites and reviewed shared-process groups against a soft five to ten minute budget. Run long units first and report oversized units intact.
- Freeze one actual build and discovery per mode and host. Give each worker its own authorized workspace, scratch/database and output directories.
- Preserve internal TSAN concurrency, single-process ASAN ordering, the 170-method/32-source AppKit group and 13-method/two-source salvage group.
- Reuse only durable, complete, immutable successes bound to the actual source, host, compiler, SDK, OS, image, environment, selection and policies. Retry missing, failed and incomplete attempts without deleting prior evidence.
- Serialize unknown or conflicting external resources. Bound the combined TSAN/ASAN pool by reviewed CPU, RAM and disk admission, rather than separate mode budgets.
- Require exact inventory once per mode, strict declared opt-ins, full normal coverage at the existing 80% gate and zero leaks. Preserve review, protection, SonarQube and release requirements.

## Scope and current hold

This packet adds the protocol, native builder/executor/command adapters and fake-only acceptance tests in five new reserved files. Existing helpers, runner authorization, CI jobs, Makefile, host variables, branch protection and the active M01 run remain unchanged. Every native command fails before file inspection or probes while the activation guard is disabled. The draft targets `release/m01` and must remain unmerged until the current G1 run is terminal and an independent activation review is complete.

The existing host policy authorizes one exact checkout and workflow. A GitHub matrix alone cannot create additional authorized physical workers. Source validation does not establish resource independence, native descendant ownership, host capacity or sanitizer equivalence. Those remain activation prerequisites, detailed in [the PR handoff](PR-recoverable-parallel-quality.md).

## Acceptance evidence

Fake Python processes must cover hard controller loss before and after success publication, timeout, inherited locks, duplicate work, unknown live helpers, incomplete XML, nonzero exit despite complete XML, diagnostic logs, evidence tampering, trusted artifact restore, failed-only retry, exact aggregate gates, resource serialization and CPU/RAM/disk admission. No Swift, game process, sanitizer, leak probe or workflow dispatch is permitted during this source-only packet.

## Links

- Paired implementation handoff: [PR-recoverable-parallel-quality.md](PR-recoverable-parallel-quality.md).
- The Orchestrator holds the approved G2 design receipt with SHA-256 `881cd106c9a9504ad9e10339350255e1f4e6496e3f7740e69da05b6fae4d8dd2`.
