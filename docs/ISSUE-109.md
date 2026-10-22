# Shorten repeated unit build waits

[Issue #109](https://github.com/stephenlclarke/elite/issues/109) tracks the explicitly authorised local runner setup.

## Problem

Recent maintained-unit GitHub jobs spent roughly thirteen to fifteen minutes compiling before runtime feedback. The MBP can retain incremental compilation data, but the existing hosted job starts on a fresh runner and a failed run does not publish the normal successful post-job cache update.

## Required result

Use an isolated local macOS runner for Stephen's internal pushes. Keep external PR jobs hosted, preserve all test selection and report checks, match Swift 6.1.2 and SDK 15.5, and retain incremental objects across failures. Keep the MBA reviewing GitHub evidence. Do not add a separate benchmark campaign or change final protected merge/release gates.

The initial prepared design linked `.build` outside the checkout. Source inspection showed that this conflicts with the existing crash collector's confinement contract. The corrected design keeps a physical in-checkout build cache and cleans all other ignored/untracked inputs. It does not relax the collector or allow external image paths.

## Validation

Focused Python tests cover trust and cache preservation boundaries. Workflow lint must pass. Actual readiness requires VM boot, pinned compiler/SDK, runner registration and online state. Measure the next required jobs, keeping cold and warm timings distinct.

## Compatibility and remaining risk

The repository variable defaults to the hosted route. There is no game, save, simulation or unit-oracle change. VM resource use must respect the main compiler lease. See [operation and isolation requirements](LOCAL-MACOS-RUNNER.md).

Guest provisioning confirmed macOS 15.7.7, VirtualMac2,1, Swift 6.1.2 and SDK 15.5. The observed Swift driver prefix is now accepted while the exact compiler identity remains required. Nine helper tests pass. Registration and actual job qualification remain pending.

Runner registration and managed restart are verified: GitHub runner `elite-mbp-vm` (ID 21) returned online and idle after a clean guest shutdown and LaunchAgent restart. The guest uses eight virtual CPUs and 10 GB RAM, with host shares, audio, USB accessories and clipboard disabled. No unit-job qualification or measured speedup is claimed yet.
