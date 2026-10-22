# Run trusted unit jobs on an isolated local Mac VM

## Motivation

Reduce build-feedback latency without weakening the existing qualification job. Keep the developer coding and the MBA reviewing the same GitHub results.

## Change

An explicit repository variable routes Stephen's internal pushes to the dedicated Apple Silicon VM. Other events remain hosted. Preflight checks the trusted push, VM identity and matching compiler/SDK before reusing an owned physical SwiftPM cache inside the checkout. Explicit cleanup removes other untracked/ignored inputs while preserving that cache and the existing crash collector's confinement contract. Existing unit commands, coverage, selection, report validation and final release gates remain unchanged.

## Validation

Run the focused Python suite and workflow lint. Record actual VM/runner readiness and the next required exact-head job separately from source checks. No speedup or unit qualification is established by a prepared workflow alone.

## Scope and risk

No gameplay or save changes. The enable variable remains off until the VM is online. Keep forks and deliberately modified external workflows away from the persistent runner. See [the issue](ISSUE-109.md) and [operator instructions](LOCAL-MACOS-RUNNER.md).

Guest provisioning confirmed macOS 15.7.7, VirtualMac2,1, Swift 6.1.2 and SDK 15.5. The observed Swift driver prefix is now accepted while the exact compiler identity remains required. Nine helper tests pass. Actual job qualification remains pending.

Runner registration and managed restart are verified: GitHub runner `elite-mbp-vm` (ID 21) returned online and idle after a clean guest shutdown and LaunchAgent restart. The guest uses eight virtual CPUs and 10 GB RAM, with host shares, audio, USB accessories and clipboard disabled. No unit-job qualification or measured speedup is claimed yet.
