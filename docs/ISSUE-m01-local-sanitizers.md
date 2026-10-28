# M01 local ASAN and TSAN execution

## Motivation

GitHub scheduling and API availability block the native sanitizer campaign even after successful ASAN preparation. The human authorized genuine local execution for both ASAN and TSAN, with ASAN first. Existing worker, preparation, process-monitor, receipt and checkpoint primitives already execute locally, but their authority and authorization records require Actions job identities.

The adapter must use a distinct owned local approval and real local session IDs. It must not fabricate GitHub environment variables, statuses or API responses. G1 remains the sole native operator; independent source and actual policy/session reviews precede activation.

## Required behavior

- Reuse existing build/discovery, one-worker shard execution, resource checks, shared leases, exact source/image/runtime checks, raw progress, strict XML/diagnostics and durable receipt recovery.
- Bind each mode to its own immutable reviewed policy, full inventory and plan, finite local session and persistent launch budget. Reject wrong source, mode, environment, allocation, plan, expiry or ownership before native execution.
- Use the reviewed 16-ID local target and mode-specific RSS monitor for both sanitizers. Keep default/GitHub TSAN's 64-ID target and original flags, every whole suite/shared cohort, internal test concurrency, assertions and declared opt-ins.
- Require a separate full-mode component validation. Preserve full quality, normal coverage, leaks, main analysis, branch protections and release publication requirements.

## Compatibility and limits

Every maintained `Tools/` input participates in runtime identity. This source change and its local authorization environment require fresh committed local preparation. The old e731 ASAN build/200-shard plan, original c15 receipts and historical TSAN results remain evidence for their original identities only. Mutable compiler caches may aid an actual fresh build; unchanged image bytes do not qualify old proof for the new profile.

The original TSAN allocation of 4 GiB per worker plus 2 GiB reserve refuses against the fixed 4.3-4.6 GiB available range; it is not a measured required peak. The new local TSAN profile reduces compiler concurrency and process retention, then measures the owned process tree against its own separately reviewed allocation. G1's candidate is 2 GiB per worker plus 2 GiB reserve. This candidate is unmeasured, and a sampled RSS ceiling is not an OS hard limit or a fit guarantee. Initial finite native qualification must prove or refute it. No further cleanup or larger-memory request is implied. See [the implementation and operator handoff](PR-m01-local-sanitizers.md).

## Controller lease startup ordering

Independent review found that authority construction ran native metadata commands and configured mutable mode storage before `local_command` acquired the shared controller lease. Its first metadata children therefore lacked the controller descriptor. Acquire the fixed physical account's existing controller lease before constructing authority, while retaining pure identity refusal before lock creation. Supply the live descriptor to the constructor before its first metadata call. A competing held lease must prevent both metadata calls and cache/worker creation.

## Local TSAN working-set profile

Use one compiler job with frontend batch mode disabled for local TSAN only. Pack at most 16 IDs unless a required whole suite/shared cohort is larger. Keep the 170-ID AppKit and 13-ID salvage process groups intact and preserve TSAN test concurrency, diagnostics and instrumentation. Extend the existing owned RSS sampler and full local component gate to thread mode using that mode's approved allocation and a matching local-policy runtime binding. Missing, wrong-mode, mismatched-budget or excessive RSS cannot qualify. Default/GitHub TSAN behavior stays unchanged.
