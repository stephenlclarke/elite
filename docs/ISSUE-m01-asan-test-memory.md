# M01 ASAN test execution within the fixed memory budget

## Motivation

The host has about 4.3-4.6 GiB available after reboot. Its existing 4 GiB worker estimate plus 2 GiB reserve refuses admission before any ASAN child starts. There is no measured ASAN working-set peak. The available memory is fixed; further cleanup or a larger host budget is outside this assignment.

The existing ASAN build uses one compiler job with batch mode disabled. Test execution already passes `--no-parallel`. A packed test process can still retain fixtures, caches and allocator state across unrelated suites. The retained 3,403-ID plan packs 1,391 atomic suites/shared cohorts into 52 processes. Running each atom separately would exceed the existing 256-job workflow limit.

## Required behavior

- Reduce the ASAN packing target from 64 IDs to 16, keeping complete suites and audited shared cohorts intact. Preserve all selectors, assertions, sanitizer instrumentation and diagnostics.
- Reuse the existing process monitor to sample aggregate resident size for fresh owned descendants. Retain the sampled maximum and fail when samples are missing or the configured worker allocation is exceeded.
- Reuse fresh PID/start/command checks before terminating any owned process. Retain failed raw evidence and require ordinary XML, cleanup and receipt qualification.
- Keep TSAN packing and non-ASAN monitoring behavior unchanged. Leave installed policies, runner operation, required checks and native qualification with G1.

## Acceptance and remaining risk

Focused Python fakes must cover exact inventory membership, indivisible groups, packing limits, process ownership, RSS units, high-water retention, missing samples, asynchronous refusal and failed child evidence. A pure calculation using the retained inventory must fit the existing matrix limit. Native peak memory and the largest indivisible cohort remain unqualified until G1 executes the reviewed profile.

The candidate external allocation is one 2 GiB worker plus a 2 GiB reserve. This is a fixed-host allocation, not a measured peak or an OS hard limit. Sampled RSS can miss transient spikes and counts shared resident pages in more than one process. See [the implementation handoff](PR-m01-asan-test-memory.md).
