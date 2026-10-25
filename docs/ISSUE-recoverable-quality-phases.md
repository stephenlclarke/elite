# Recover completed quality work after a later failure

## Motivation

A late sanitizer failure can discard hours of completed work. At published `38ae83ec3517a1085e2d40e315a4c54260bcddac`, normal/coverage takes 2988.871 seconds. The retained historical full ThreadSanitizer process took 16048.589398958255 seconds including process overhead. These are different source-scoped examples, not a prediction for the new grouping policy.

## Scope

ASAN already checkpoints complete whole-suite batches (35 at the historical 3395-method inventory). TSAN is still one indivisible concurrent process. Normal/coverage and leaks have no reusable complete phase receipt. Re-running `make ci` therefore repeats normal work before reaching existing sanitizer checkpoints.

Keep the existing immutable success validation and executor lock. Extend TSAN with recoverable whole-suite groups, and add normal/coverage and leak phase receipts. Every required phase still has to pass for `make ci` to pass. Native runs, runner settings and the live M01 execution are outside this authoring task.

## Compatibility and coverage decision

The user requested recoverable ASAN/TSAN steps. The lead approved partitioned TSAN as the default, with full-concurrent TSAN separately callable. A process restart cannot preserve arbitrary races between tests in different processes. Grouped coverage is explicitly different; no equivalence claim or hidden mandatory full-suite tail is made.

Audited AppKit/renderer users stay together (33 source files, 172 methods after the composed M02 application-path tests; the original 32-file/170-method audit remains historical evidence). Both salvage consumers of the shared release actor stay together (two files, 13 methods). Exact source hashes and complete group memberships must still match discovery; a new AppKit or shared salvage consumer requires review. Whole suites and nested suites remain intact, and explicit task-group concurrency inside tests is unchanged. Immutable catalog initialization can still be exercised in multiple processes; no comprehensive cross-suite equivalence is inferred.

## Validation and remaining risks

Only Python fake-boundary unit execution and independent source review are authorized on this branch. Native command compatibility, actual duration, memory use and current-head sanitizer/leak results remain unqualified until the sole executor integrates and executes the patch after preserving the current run. A 100-method target cannot bound a slow method or oversized suite. Historical concurrent method-time sums are not reliable process wall estimates.

## Links

Companion: [implementation and handoff](PR-recoverable-quality-phases.md). Based on [PR25](https://github.com/stephenlclarke/elite/pull/25); this tooling packet does not merge or release PR25.
