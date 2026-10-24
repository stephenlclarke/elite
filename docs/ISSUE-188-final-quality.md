# Issue 188: current SH025 cargo fixture

## Motivation

The catalogue assertion expects35tonnes for the approved current SH025, whose authored performance now declares92. These observations come from required quality run [40054216562](https://github.com/stephenlclarke/elite/actions/runs/40054216562) at `51fbcee474854c190fb748e101f3b8c27d84718a`. Its full coverage execution failed separately with stack exhaustion; later sanitizer and leak gates are not established.

## Implementation and review

Update the current-cargo expectation to92. Historical source profiles and catalogue validation remain unchanged. Independent review of the combined nine-code-file delta is clear after correcting eager diagnostic work on passing captures. All changes remain in the same M01 packet in [PR25](https://github.com/stephenlclarke/elite/pull/25).

## Validation and compatibility

The single approved normal affected-unit batch is pending. It includes all eight assertion-bearing methods, the actual stack-fault owning evacuation method and directly affected fixture, identity and quote semantics. No passing execution, release qualification or issue closure is claimed. Existing524/40/59method evidence remains limited to its original scopes. Actor ownership, native authority, original assertions, runtime stack/concurrency settings and required quality gates remain unchanged.

## Links and remaining risks

[Issue 188](https://github.com/stephenlclarke/elite/issues/188); [PR25](https://github.com/stephenlclarke/elite/pull/25). The manual capture cause remains pending actual evidence, and issue185 remains open pending qualification of the source lifetime correction. Final full quality, protected merge, main-only SonarQube and signed/notarized release publication remain required.
