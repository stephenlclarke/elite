# M01 local sanitizer components and full CI quality

> Superseded CI routing: the user removed ASAN and TSAN requirements on 28 October 2026. The active workflow no longer consumes this sanitizer bridge. The contract and results below are retained as history; see [current CI scope](PR-ci-without-sanitizers.md).

## Motivation

G1 must execute ASAN and TSAN locally without GitHub scheduling or transport. The local adapter can qualify each complete mode, but the required GitHub `quality` workflow still expects sanitizer matrix jobs and two GitHub mode plans. A local component alone cannot establish full quality or authorize release publication.

The final source must also contain the normal/leak working-set profile before either local sanitizer prepares its runtime. Every maintained tool participates in executable identity. A later integration-helper edit would invalidate fresh local preparation and force unnecessary native replay.

## Required behavior

- Add one explicitly reviewed full-quality backend. Reverify both original local components in place, including every receipt, XML outcome, diagnostic, image, source/dependency input, allocation and sampled resident-memory result. Keep their original tested head and historical local authority.
- Accept a separate current CI head only through an immutable owned binding with identical complete Git trees, identical executable/dependency blobs and compatible full semantic environments. Reject drift in any tracked file, including documentation and the completion ledger.
- Require a real dedicated component-verification job before accepting intentional sanitizer job skips. Missing/failed verification, partial unions, unexpected skips and failed required jobs must fail the real quality result.
- Execute normal tests, full inventory/coverage and zero leaks for the actual CI head. Give normal and leaks independent reviewed build profiles, admission budgets and owned process-tree monitoring. Preserve runtime/test concurrency, diagnostics, selectors and the existing coverage/leak gates.
- Preserve the required CI wrapper, actual-main Sonar analysis with the exact commit SHA, release publisher, reviews and branch protections.

## Ownership and limits

Root owns source composition and the completion ledger. G1 owns all native execution and operator policies, bindings, sessions, workers and caches. MBA reviews the frozen source and actual operator inputs independently. MC1 implements this bounded source packet and runs focused fakes only.

The candidate normal and leak allocations are each a separately reviewed 2 GiB worker budget plus 2 GiB reserve. They remain unmeasured. A sampled RSS sum is neither an OS hard limit nor a fit guarantee. See [the implementation and handoff](PR-m01-local-quality-bridge.md).
