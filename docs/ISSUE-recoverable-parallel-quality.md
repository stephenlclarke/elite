# Recoverable parallel quality execution

## Motivation

The existing sanitizer helper executes packing-index batches serially under one global executor lock. A long failed campaign leaves later work unexecuted, and GitHub retries operate at the campaign job boundary. Passed work needs stable, independently recoverable proofs rather than a batch number tied to packing order.

Retained G2 planning evidence describes 3,403 methods in 36 serial groups. One indivisible consumer took about 5,099 seconds; another retained 98-ID batch took about 8,966 seconds. These are planning hints from the existing run, not performance results for this change. More workers cannot make one indivisible consumer finish sooner.

## Required behavior

- Pack whole suites and unchanged audited process groups against a soft 300-600 second target, longest first. Keep oversized units intact.
- Build/discover once per mode and host; retain a complete durable scratch bundle and restore private worker copies without recompiling completed preparation.
- Preserve internal TSAN concurrency, ASAN ordering, the 170-method/32-source AppKit group and the 13-method/two-source salvage group.
- Reuse only exact, immutable, exit-zero successes bound to actual inputs, host, toolchain, SDK, OS, image, controls, selection and relevant policies. Retry only missing, failed or incomplete work and retain original evidence.
- Bound both modes and all controllers through one host pool. Serialize unknown or conflicting external resources. Treat timing hints and worker placement as planning metadata.
- Bind physical admission to a separately reviewed manual workflow, exact source and workflow bytes, owned host policy and exact run-attempt assignment before checkout.
- Retain independent per-shard artifacts through an external trusted digest, and require exact both-mode inventory plus full normal coverage at the existing 80% gate and zero leaks. Cancelled or missing work cannot become a physical pass.

## Implemented scope and hold

[PR #242](https://github.com/stephenlclarke/elite/pull/242) implements the planner, durable receipts/builds/phases, bounded workers, actual native adapters, pre-job authorizer, artifact transport and manual workflow routing. Changes are limited to the five original reserved new files plus the separately reserved `native_runner.py` policy extension and its tests. Legacy CI authorization remains the default.

Physical execution remains disabled in code and defaults off in the workflow. No host provisioning, routing-variable edit, workflow dispatch, native build, test, sanitizer, leak probe, GUI or performance measurement is part of this packet. The existing M01 checkout, helper bytes, policy and qualified receipts remain untouched. This PR targets `release/m01` and stays draft/unmerged pending independent review and a separate safe activation.

## Acceptance evidence

The focused local packet has 64 passing fake-only test methods: 50 recovery/native-adapter/workflow tests plus 14 selected existing/new authorization tests. Faults cover controller loss, timeout, duplicate/inherited claims, unknown children, invalid XML and exits, diagnostic logs, output/path/permission tampering, failed-only resume, durable mode restoration, phase retry with zero execution, observed helper image mismatch, growing-worker headroom, stale assignments and held/cancelled final gates. Exact receipts and hashes accompany the frozen Orchestrator handoff.

See [the implementation handoff](PR-recoverable-parallel-quality.md) for protocol details, operational prerequisites and remaining validation.
