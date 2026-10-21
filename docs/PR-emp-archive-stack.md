# Separate EMP archive capture lifetimes in nested saves

The absent archive guard now runs before entering capture and retains the original scan for EMP source, crew-pod or spawn-producer actors. Present archives retain a private COW candidate, initial validity check, per-record capture, final validity check and the original publication point. A non-inlined inout record helper contains the unchanged hull, recovered-hull and pod capture operations. A separate non-inlined scene-check helper runs after capture returns. Mutating receivers borrow the existing Game rather than requesting a separate value receiver.

The new `EMPArchiveStackTests.swift` exercises real GameRuntime timer callback saves with absent and actual pulse-created EMP archives, reload without duplicate payment, blocked-writer rollback/retry, stray EMP actor rejection and invalid archive rejection without publication. It copies the existing private durable timer fixture into its own scoped fixture; the original crashing timer test remains unchanged. The EMP scene uses the existing catalogue-backed equipment/release boundary, not fabricated archive authority.

Source review must compare all capture operations, guard ordering and assignment-before-scene-validation semantics. G1 must run the new tests alongside the unchanged original timer tests and existing EMP persistence/recovery regressions, then inspect exact compiled frame placement. Source factoring alone does not establish stack reduction or CI success. No compiler, test, native or debugger execution was performed by this worker.

[Issue and crash context](ISSUE-emp-archive-stack.md).
