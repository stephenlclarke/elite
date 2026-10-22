# Run trusted unit jobs on an isolated local Mac VM

## Motivation

Reduce build-feedback latency without weakening the existing qualification job. Keep the developer coding and the MBA reviewing the same GitHub results.

## Change

An explicit repository variable routes Stephen's internal pushes to the dedicated Apple Silicon VM. Other events remain hosted. Preflight checks the trusted push, VM identity and matching compiler/SDK before linking an external-to-checkout, guest-local SwiftPM cache. Existing unit commands, coverage, selection, report validation and final release gates remain unchanged.

## Validation

Run the focused Python suite and workflow lint. Record actual VM/runner readiness and the next required exact-head job separately from source checks. No speedup or unit qualification is established by a prepared workflow alone.

## Scope and risk

No gameplay or save changes. The enable variable remains off until the VM is online. Keep forks and deliberately modified external workflows away from the persistent runner. See [the issue](ISSUE-109.md) and [operator instructions](LOCAL-MACOS-RUNNER.md).
