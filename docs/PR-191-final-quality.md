# Pr 191: manual measured ore capture

## Motivation

The actual native journey fails its original captures>=12 assertion. Existing logs do not establish the failing capture gate or current body state. These observations come from required quality run [40054216562](https://github.com/stephenlclarke/elite/actions/runs/40054216562) at `51fbcee474854c190fb748e101f3b8c27d84718a`. Its full coverage execution failed separately with stack exhaustion; later sanitizer and leak gates are not established.

## Implementation and review

Retain the hard capture assertion and add bounded failure-only capture, body, velocity, spin and current-custody diagnostics. This is observability pending an actual result, not a claimed capture fix or relaxed intake rule. Independent review of the combined nine-code-file delta is clear after correcting eager diagnostic work on passing captures. All changes remain in the same M01 packet in [PR25](https://github.com/stephenlclarke/elite/pull/25).

## Validation and compatibility

The single approved normal affected-unit batch is pending. It includes all eight assertion-bearing methods, the actual stack-fault owning evacuation method and directly affected fixture, identity and quote semantics. No passing execution, release qualification or issue closure is claimed. Existing524/40/59method evidence remains limited to its original scopes. Actor ownership, native authority, original assertions, runtime stack/concurrency settings and required quality gates remain unchanged.

## Links and remaining risks

[Issue 191](https://github.com/stephenlclarke/elite/issues/191); [PR25](https://github.com/stephenlclarke/elite/pull/25). The manual capture cause remains pending actual evidence, and issue185 remains open pending qualification of the source lifetime correction. Final full quality, protected merge, main-only SonarQube and signed/notarized release publication remain required.
