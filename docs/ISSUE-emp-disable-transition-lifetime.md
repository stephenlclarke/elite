# EMP zero-power admission retains the pulse-application stack frame

Validation 348 compiled the complete candidate and then failed with an actual SIGBUS in the unchanged full-stock native Cobra regression. Its qualified crash report states `Thread stack size exceeded`: the real tick called the original 800-frame EMP driver, then `advanceEMPCharge`, `emitEMPPulse`, `buildEMPPulseEffects`, `applyElectricalPulse`, `disableEMPHull` and `prepareEMPDisable`. The final crash was inside the first body lookup in preparation. Four methods had no terminal result; the batch is failed, with 44 methods/52 cases separately qualified as passed and a separate residual save/load assertion failure.

Read-only disassembly of the preserved coverage-enabled executable shows that `applyElectricalPulse` retains a fixed 12,496-byte frame plus metadata-sized temporaries while it calls the disable transition. Its transient whole-Game slot supports actual read-only queries and remains reserved even after those temporary values are destroyed. The exact runtime sizes and total peak usage were not measured. This evidence does not establish that a proposed source change passes or improves performance.

Finish applying the actual hit and return a typed pending-zero result. Its immediate caller, still inside the original private atomic candidate, must perform the same disable admission and Commander validation before any next contact. Preserve every guard, resource debit, incident, catalogue pin, custody rule, crew sampling, contact order and rollback boundary. Keep the full-stock test, its inputs and all assertions unchanged; do not increase thread stack size, serialize or make the test asynchronous.

[PR handoff](PR-emp-disable-transition-lifetime.md).
