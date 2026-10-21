# fix(persistence): avoid overlapping provider ledger access

## Result and implementation

Provider reference normalization reads each complete dictionary entry into a local value. `bindingReferences` computes the normalized snapshot before the entry is written back. This removes the overlapping dictionary modification/read reported by focused validation run 314 while retaining the original reference resolution and all other entry fields.

## Scope and compatibility

Only the reported `normalizeProviderReferences(protection:)` read/compute/write hunk in `NPCPersistenceLedger.swift` and this [issue/PR pair](ISSUE-npc-provider-ledger-exclusivity.md) change. Base: `c4478d96aa5c5088e7a15d4a7ddc8feaa6e036ed`. Resource amounts, physical/electrical clocks, ownership, offers, terminal state, validation and whole-candidate failure semantics are unchanged. No production readiness gate or other source task changes.

## Validation

Formatter/parser, scoped strict source lint, Markdown and diff/scope checks were performed. The compiler diagnostic was inspected in `/tmp/elite-native-crimbo-lifecycle-focused-314/candidate-314-attempt-01.log`. This worker ran no compiler, typecheck, test discovery/execution or native job. G1 owns run closure and the eventual meaningful affected validation.

Any eventual project PR still requires actual completed clean `@codex review` cycles and passing final-head required checks and approvals before protected merge, without bypass.
