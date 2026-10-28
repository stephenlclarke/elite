# M01 local ASAN and TSAN execution

## Motivation

GitHub scheduling and API availability block the native sanitizer campaign even after successful ASAN preparation. The human authorized genuine local execution for both ASAN and TSAN, with ASAN first. Existing worker, preparation, process-monitor, receipt and checkpoint primitives already execute locally, but their authority and authorization records require Actions job identities.

The adapter must use a distinct owned local approval and real local session IDs. It must not fabricate GitHub environment variables, statuses or API responses. G1 remains the sole native operator; independent source and actual policy/session reviews precede activation.

## Required behavior

- Reuse existing build/discovery, one-worker shard execution, resource checks, shared leases, exact source/image/runtime checks, raw progress, strict XML/diagnostics and durable receipt recovery.
- Bind each mode to its own immutable reviewed policy, full inventory and plan, finite local session and persistent launch budget. Reject wrong source, mode, environment, allocation, plan, expiry or ownership before native execution.
- Preserve ASAN's 16-ID target and RSS monitor, TSAN's 64-ID target and original instrumentation/flags, every whole suite/shared cohort, and all assertions and declared opt-ins.
- Require a separate full-mode component validation. Preserve full quality, normal coverage, leaks, main analysis, branch protections and release publication requirements.

## Compatibility and limits

Every maintained `Tools/` input participates in runtime identity. This source change and its local authorization environment require fresh committed local preparation. The old e731 ASAN build/200-shard plan, original c15 receipts and historical TSAN results remain evidence for their original identities only. Mutable compiler caches may aid an actual fresh build; unchanged image bytes do not qualify old proof for the new profile.

The reviewed ASAN allocation is 2 GiB per worker plus 2 GiB reserve. TSAN retains its separately reviewed 4 GiB worker allocation plus 2 GiB reserve. These are allocations, not measured peaks. The TSAN allocation will refuse admission against the fixed 4.3-4.6 GiB available range. The local adapter does not lower it; a genuine smaller TSAN working-set profile needs a separate bounded change and actual qualification. No further cleanup or larger-memory request is implied. See [the implementation and operator handoff](PR-m01-local-sanitizers.md).
