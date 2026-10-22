# Shorten repeated unit build waits

[Issue #109](https://github.com/stephenlclarke/elite/issues/109) tracks the explicitly authorised local runner setup.

## Problem

Recent maintained-unit GitHub jobs spent roughly thirteen to fifteen minutes compiling before runtime feedback. The MBP can retain incremental compilation data, but the existing hosted job starts on a fresh runner and a failed run does not publish the normal successful post-job cache update.

## Required result

Use an isolated local macOS runner for Stephen's internal pushes. Keep external PR jobs hosted, preserve all test selection and report checks, match Swift 6.1.2 and SDK 15.5, and retain incremental objects across failures. Keep the MBA reviewing GitHub evidence. Do not add a separate benchmark campaign or change final protected merge/release gates.

## Validation

Focused Python tests cover trust and cache preservation boundaries. Workflow lint must pass. Actual readiness requires VM boot, pinned compiler/SDK, runner registration and online state. Measure the next required jobs, keeping cold and warm timings distinct.

## Compatibility and remaining risk

The repository variable defaults to the hosted route. There is no game, save, simulation or unit-oracle change. VM resource use must respect the main compiler lease. See [operation and isolation requirements](LOCAL-MACOS-RUNNER.md).
