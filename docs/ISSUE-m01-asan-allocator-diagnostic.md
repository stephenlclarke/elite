# Bounded allocator observations for the stopped ASAN cohort

## Evidence gap

Three local ASAN attempts stopped at their reviewed RSS guards. The saved records show the refusal totals, process identities and test progress. They do not contain allocation stacks or a per-fixture heap timeline. The last 2.25 GiB attempt passed the mission-station methods and reached the salvage authority parameterized method, but did not reach any panel or icon test. These stopped totals are lower bounds, not completed peaks. The renderer change remains unvalidated.

The source review found no demonstrated fixture ownership defect that justifies another fix. Existing snapshots protect required custody assertions. Repeated catalogue/profile references do not prove deep copies, and high body-exit counters would not prove a leak. Further budget escalation or a speculative cache, autorelease or test-selection change would not answer the cause question.

## Required diagnostic

Add one test-only, exact opt-in helper using the installed public ASAN allocator counter/statistics interfaces. Record bounded process-wide facts around the existing mission and salvage method boundaries. Preserve every fixture, assertion, argument, selector, atomic cohort, concurrency setting, sanitizer option and guard. Do not add allocation hooks, stack logging, process attachment, a profiler or a product hook.

The diagnostic must stay off by default. It must stop its own logging if symbols are unavailable, keep one process-wide 64-record ceiling and print at most two accumulated statistics dumps. Its output must not be treated as ordinary ASAN qualification. [Implementation and interpretation limits](PR-m01-asan-allocator-diagnostic.md).
