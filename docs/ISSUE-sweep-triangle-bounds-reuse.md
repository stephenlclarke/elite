# Repeated triangle bounds during native cutter clearance checks

A two-second sample of the existing coverage-enabled debug test process in validation 342 found the native EMP test in its original cutter/depletion loop at `NativeEMPViewTests.swift:323`, after reaching the real work hold. Its continuation spent 454 of 474 sampled stacks in the work-guidance obstacle sweep. This short sample identifies active geometry work; it does not establish eventual completion, production frame rate, or a measured improvement.

Within `HullSweepSafety.triangleDistance`, every visited BVH node recomputes the same incoming triangle's bounds. The triangle's three vertices are immutable and its bounds getter performs only deterministic component minimum/maximum calculations. Compute that exact value once per invocation and retain the existing traversal and clearance proof.

The original 600/640-second validation continues unchanged. This isolated source change does not alter its inputs, budgets, controls, source or outcome. Preserve that run's terminal evidence and compiled artifacts before any later composition or execution.

[PR handoff](PR-sweep-triangle-bounds-reuse.md).
