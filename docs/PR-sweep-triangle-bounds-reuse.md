# Reuse immutable triangle bounds within the existing BVH traversal

`triangleDistance` now computes the incoming triangle's bounds once before its node loop. Each existing node comparison receives that same value. The pure getter's minimum/maximum expression, triangle distance calculation, floating-point comparison, node ordering, child ordering, containment checks, budgets, work counters, exceptions and result remain unchanged. No persistent cache or controller change is introduced.

The source motivation is validation 342's single two-second coverage/debug process sample, captured before this isolated change. Its actual phase is the original 1200-frame cutter/depletion loop, after the approach and real hold. The earlier observation metadata incorrectly described the approach loop; corrected metadata retains that original label and correction while the raw sample remains unchanged. No speedup, production frame rate, timeout resolution or completed native test outcome is claimed.

Source checks compare the complete function with the parent after reversing only the two-line change and verify that all other source files and tests are unchanged. Existing meaningful regression candidates cover exact-player triangle-pair pruning and containment, continuous moving-obstacle rejection, zero-clearance contact refusal, exhausted budgets and raw capital geometry. No compiler, test, native capture or renderer job runs for this isolated leaf before source review and validation 342's terminal preservation. Later focused execution and the maintained full quality gates remain required.

[Issue](ISSUE-sweep-triangle-bounds-reuse.md).
