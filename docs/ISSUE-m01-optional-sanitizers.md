# Restore the original optional local sanitizer suites

## Problem

The public `make threads` and `make address` targets still route through the later checkpoint and partition controller. The human requested the original full-suite commands for local use on another Mac, disabled by default, without shard plans or operational overhead. See [PR232](https://github.com/stephenlclarke/elite/pull/232).

## Required behavior

Restore the original whole-suite Swift commands. Keep thread sanitizer concurrency and Address Sanitizer's `--no-parallel` and `ASAN_OPTIONS=detect_leaks=0`. Provide individual and combined local targets and an explicit default-off CI opt-in. Retain the normal required tests, coverage, leaks and static checks. Do not execute sanitizers as part of this change or require runner policy/proof machinery for standalone local use.

## Compatibility and validation

Keep `threads-full` as an alias. Preserve historical controller code and evidence for its existing consumers. Verify actual Make command execution with a fake Swift executable, default/opt-in dry runs and failure propagation. This checks the interface, not sanitizer success on another Mac. See [implementation](PR-m01-optional-sanitizers.md).
